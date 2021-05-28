require "./node"
require "./app"
require "./macros"
require "./screen/*"
require "./widget"
require "./widget/element/pos"

module Crysterm
  # Represents a screen. `Screen` and `Widget` are two lowest-level classes after `EventEmitter` and `Widget`.
  class Screen
    include EventHandler

    include Instance
    include Focus
    include Attributes
    include Angles
    include Rendering
    include Drawing
    include Cursor
    include Widget::Element::Pos

  ######### COMMON WITH NODE

  # Widget's children `Widget`s.
  property children = [] of Widget

  property? destroyed = false

  # Is this `Screen` detached?
  #
  # Screen is a self-sufficient element, so by default it is always considered 'attached'.
  # This value could in the future be used to maybe hide/deactivate screens temporarily etc.
  property? detached = false

  def append(element)
    insert element
  end

  def append(*elements)
    elements.each do |el|
      insert el
    end
  end

  def insert(element, i = -1)

    # XXX Never triggers. But needs to be here for type safety.
    # Hopefully can be removed when Screen is no longer parent of any Widgets.
    if element.is_a? Screen
      raise "Unexpected"
    end

    element.detach

    element.screen = self

    # if i == -1
    #  @children.push element
    # elsif i == 0
    #  @children.unshift element
    # else
    @children.insert i, element
    # end

    emt = uninitialized Widget -> Nil
    emt = ->(el : Widget) {
      n = el.detached? != @detached
      el.detached = @detached
      el.emit Crysterm::Event::Attach if n
      el.children.each do |c|
        emt.call c
      end
    }
    emt.call element

    unless self.focused
      self.focused = element
    end
  end

  # Removes node from its parent.
  # This is identical to calling `#remove` on the parent object.
  def detach
    @parent.try { |p| p.remove self }
  end

  def remove(element)
    return if element.parent != self

    return unless i = @children.index(element)

    element.clear_pos

    element.parent = nil
    @children.delete_at i

    # TODO Enable
    # if i = @screen.clickable.index(element)
    #  @screen.clickable.delete_at i
    # end
    # if i = @screen.keyable.index(element)
    #  @screen.keyable.delete_at i
    # end

    element.emit(Crysterm::Event::Reparent, nil)
    emit(Crysterm::Event::Remove, element)
    # s= @screen
    # raise Exception.new() unless s
    # screen_clickable= s.clickable
    # screen_keyable= s.keyable

    emt = ->(el : Widget) {
      n = el.detached? != @detached
      el.detached = true
      # TODO Enable
      # el.emit(Event::Detach) if n
      # el.children.each do |c| c.emt end # wt
    }
    emt.call element

    if focused == element
      rewind_focus
    end
  end

  # Prepends node to the list of children
  def prepend(element)
    insert element, 0
  end

  # Adds node to the list of children before the specified `other` element
  def insert_before(element, other)
    if i = @children.index other
      insert element, i
    end
  end

  # Adds node to the list of children after the specified `other` element
  def insert_after(element, other)
    if i = @children.index other
      insert element, i + 1
    end
  end

  ######### END OF COMMON WITH SCREEN

    # Associated `Crysterm` instance. The default app object
    # will be created/used if it is not provided explicitly.
    property! app : App

    # Is focused element grabbing and receiving all keypresses?
    property grab_keys = false

    # Are keypresses prevented from being sent to any element?
    property lock_keys = false

    # Array of keys to ignore when keys are locked or grabbed. Useful for defining
    # keys that will always execute their action (e.g. exit a program) regardless of
    # whether keys are locked.
    property ignore_locked = Array(Tput::Key).new

    # Currently hovered element. Best set only if mouse events are enabled.
    @hover : Widget? = nil

    property show_fps : Tput::Point? = Tput::Point[-1,0]
    property? show_avg = true

    property optimization : OptimizationFlag = OptimizationFlag::None

    def initialize(
      @app = App.global(true),
      @auto_padding = true,
      @tab_size = 4,
      @dock_borders = false,
      ignore_locked : Array(Tput::Key)? = nil,
      @lock_keys = false,
      title = nil,
      @cursor = Tput::Namespace::Cursor.new,
      optimization = nil
    )
      bind

      ignore_locked.try { |v| @ignore_locked += v }
      optimization.try { |v| @optimization = v }

      #@app = app || App.global true
      # ensure tput.zero_based = true, use_bufer=true
      # set resizeTimeout

      # Tput is accessed via app.tput

      #super() No longer calling super, we are not subclass of Widget any more

      @tabc = " " * @tab_size

      # _unicode is app.tput.features.unicode
      # full_unicode? is option full_unicode? + _unicode

      # Events:
      # addhander,

      self.title = title if title

      app.on(Crysterm::Event::Resize) do
        alloc
        render

        # XXX Can we replace this with each_descendant?
        f = uninitialized Widget | Screen -> Nil
        f = ->(el : Widget | Screen ) {
          el.emit Crysterm::Event::Resize
          el.children.each { |c| f.call c }
        }
        f.call self
      end

      # TODO Originally, these exist. See about reenabling them.
      #app.on(Crysterm::Event::Focus) do
      #  emit Crysterm::Event::Focus
      #end
      #app.on(Crysterm::Event::Blur) do
      #  emit Crysterm::Event::Blur
      #end
      #app.on(Crysterm::Event::Warning) do |e|
      #  emit e
      #end

      _listen_keys
      # _listen_mouse # XXX

      enter
      post_enter

      spawn render_loop
    end

    # This is for the bottom-up approach where the keys are
    # passed onto the focused widget, and from there eventually
    # propagated to the top.
    # def _listen_keys
    #  app.on(Crysterm::Event::KeyPress) do |e|
    #    el = focused || self
    #    while !e.accepted? && el
    #      # XXX emit only if widget enabled?
    #      el.emit e
    #      el = el.parent
    #    end
    #  end
    # end

    # And this is for the other/alternative method where the screen
    # first gets the keys, then potentially passes onto children
    # elements.
    def _listen_keys(el : Widget? = nil)
      if (el && !@keyable.includes? el)
        el.keyable = true
        @keyable.push el
      end

      return if @_listenedKeys
      @_listenedKeys = true

      # NOTE: The event emissions used to be reversed:
      # element + screen
      # They are now:
      # screen, element and el's parents until one #accept!s it.
      # After the first keypress emitted, the handler
      # checks to make sure grab_keys, lock_keys, and focused
      # weren't changed, and handles those situations appropriately.
      app.on(Crysterm::Event::KeyPress) do |e|
        if @lock_keys && !@ignore_locked.includes?(e.key)
          next
        end

        grab_keys = @grab_keys
        if !grab_keys || @ignore_locked.includes?(e.key)
          emit_key self, e
        end

        # If something changed from the screen key handler, stop.
        if (@grab_keys != grab_keys) || @lock_keys || e.accepted?
          next
        end

        # Here we pass the key press onto the focused widget. Then
        # we keep passing it through the parent tree until someone
        # `#accept!`s the key. If it reaches the toplevel Widget
        # and it isn't handled, we drop/ignore it.
        focused.try do |el|
          while el && el.is_a? Widget
            if el.keyable?
              emit_key el, e
            end

            if e.accepted?
              break
            end

            el = el.parent
          end
        end
      end
    end

    # Emits a Event::KeyPress as usual and also emits an event for
    # the individual key, if any.
    #
    # This allows listeners to not only listen for a generic
    # `Event::KeyPress` and then check for `#key`, but they can
    # directly listen for e.g. `Event::KeyPress::CtrlP`.
    @[AlwaysInline]
    def emit_key(el, e : Event)
      if el.handlers(e.class).any?
        el.emit e
      end
      if e.key
        Crysterm::Event::KeyPress::Key_events[e.key]?.try do |keycls|
          if el.handlers(keycls).any?
            el.emit keycls.new e.char, e.key, e.sequence
          end
        end
      end
    end

    def enable_keys(el = nil)
      _listen_keys(el)
    end

    def enable_input(el = nil)
      # _listen_mouse(el)
      _listen_keys(el)
    end

    # TODO Empty for now
    def key(key, handler)
    end

    def once_key(key, handler)
    end

    def remove_key(key, wrapper)
    end

    def enter
      # TODO make it possible to work without switching the whole
      # app to alt buffer.
      return if app.tput.is_alt

      if !cursor._set
        if cursor.shape
          cursor_shape cursor.shape, cursor.blink
        end
        if cursor.color
          cursor_color cursor.color
        end
      end

      # XXX Livable, but boy no.
      {% if flag? :windows %}
        `cls`
      {% end %}

      at = app.tput
      app.tput.alternate_buffer
      app.tput.put(&.keypad_xmit?) # enter_keyboard_transmit_mode
      app.tput.put(&.change_scroll_region?(0, height - 1))
      app.tput.hide_cursor
      app.tput.cursor_pos 0, 0
      app.tput.put(&.ena_acs?) # enable_acs

      alloc
    end

    # Allocates screen buffers (a new pending/staging buffer and a new output buffer).
    def alloc(dirty = false)
      # Initialize @lines better than this.
      rows.times do |i|
        col = Row.new
        columns.times do
          col.push Cell.new
        end
        @lines.push col
        @lines[-1].dirty = dirty
      end

      # Initialize @lines better than this.
      rows.times do |i|
        col = Row.new
        columns.times do
          col.push Cell.new
        end
        @olines.push col
        @olines[-1].dirty = dirty
      end

      app.tput.clear
    end

    # Reallocates screen buffers and clear the screen.
    def realloc
      alloc dirty: true
    end

    def leave
      # TODO make it possible to work without switching the whole
      # app to alt buffer. (Same note as in `enter`).
      return unless app.tput.is_alt

      app.tput.put(&.keypad_local?)

      if (app.tput.scroll_top != 0) || (app.tput.scroll_bottom != height - 1)
        app.tput.set_scroll_region(0, app.tput.screen.height - 1)
      end

      # XXX For some reason if alloc/clear() is before this
      # line, it doesn't work on linux console.
      app.tput.show_cursor
      alloc

      # TODO Enable all in this function
      # if (this._listened_mouse)
      #  app.disable_mouse
      # end

      app.tput.normal_buffer
      if cursor._set
        app.tput.cursor_reset
      end

      app.tput.flush

      # :-)
      {% if flag? :windows %}
        `cls`
      {% end %}
    end

    # Debug helpers/setup
    def post_enter
    end

    # Returns current screen width.
    # XXX Remove in favor of other ways to retrieve it.
    def columns
      # XXX replace with a per-screen method
      app.tput.screen.width
    end

    # Returns current screen height.
    # XXX Remove in favor of other ways to retrieve it.
    def rows
      # XXX replace with a per-screen method
      app.tput.screen.height
    end

    # Returns current screen width.
    # XXX Remove in favor of other ways to retrieve it.
    def width
      columns
    end

    # Returns current screen height.
    # XXX Remove in favor of other ways to retrieve it.
    def height
      rows
    end

    def _get_pos
      self
    end

    ##### Unused parts: just compatibility with `Widget` interface.
    def clear_pos
    end

    property border : Border?

    # Inner/content positions:
    # XXX Remove when possible
    property ileft = 0
    property itop = 0
    property iright = 0
    property ibottom = 0
    #property iwidth = 0
    #property iheight = 0

    # Relative positions are the default and are aliased to the
    # left/top/right/bottom methods.
    getter rleft = 0
    getter rtop = 0
    getter rright = 0
    getter rbottom = 0
    # And these are the absolute ones; they're also 0.
    getter aleft = 0
    getter atop = 0
    getter aright = 0
    getter abottom = 0

    property overflow = Overflow::Ignore

    ##### End of unused parts.

    def hidden?
      false
    end

    def child_base
      0
    end

    # XXX for now, this just forwards to parent. But in reality,
    # it should be able to have its own title, and when it goes
    # in/out of focus, that title should be set/restored.
    def title
      @app.title
    end

    def title=(arg)
      @app.title = arg
    end

    def sigtstp(callback)
      app.sigtstp {
        alloc
        render
        app.lrestore_cursor :pause, true
        callback.call if callback
      }
    end
  end
end