module Crysterm
  # This file contains definitions of various Crysterm classes that are important, but not
  # big or complex enough to warrant being in individual/dedicated files.
  #
  # Initially these contents were inside `module Namespace`, which was then `include`d
  # from `class Crysterm`. However, this separation was unnecessary, and class names were
  # reported as having "Namespace" as part of their name.
  #
  # This is now a standalone file which populates the Crysterm namespace directly. The
  # content has been left here for now (instead of being moved to `src/crysterm.cr`)
  # not to overwhelm users when first checking out the project and opening that file.

  # Rendering and drawing optimization flags.
  #
  # Smart CSR: Attempt to perform CSR optimization on all possible elements,
  # and not just on full-width ones, i.e. those with uniform cells to their sides.
  # This is known to cause flickering with elements that are not full-width, but
  # it is more optimal for terminal rendering.
  #
  # Fast CSR: Enable CSR on any element within 20 columns of the screen edges on either side.
  # It is faster than smart_csr, but may cause flickering depending on what is on
  # each side of the element.
  #
  # BCE: Attempt to perform back_color_erase optimizations for terminals that support it.
  # It will also work with terminals that don't support it, but only on lines with
  # the default background color. As it stands with the current implementation,
  # it's uncertain how much terminal performance this adds at the cost of code overhead.
  @[Flags]
  enum OptimizationFlag
    FastCSR
    SmartCSR
    BCE
  end

  # Type of layout to use in an instance of `Widget::Layout`.
  # NOTE Widget::Layout could be split into 2 separate files/classes, and also
  # additional variations of layouts could be added.
  enum LayoutType
    Inline # Masonry-like
    Grid   # Table-like
  end

  # Overflow behavior when rendering and drawing elements.
  enum Overflow
    Ignore        # Render without changes (part goes out of screen and is not visible)
    ShrinkWidget  # Make the Widget smaller to fit
    SkipWidget    # Do not render that widget
    StopRendering # End rendering cycle (leave current and remaining widgets unrendered)
    MoveWidget    # Move widget so that it doesn't overflow, if possible (e.g. auto-completion popups)
    # TODO Check whether StopRendering / SkipWidget work OK with things like focus etc.
    # They should be skipped in focus list if they are not rendered, of course.
  end

  # Docking behavior when borders don't have the same color
  enum DockContrast
    Ignore   # Just render, colors on adjacent cells will be different
    DontDock # Do not perform docking (leave default look)
    Blend    # Blend/mix colors for as smooth a transition as possible
  end

  # Class for the complete style of a widget.
  class Style
    class_property default = new # Default style for all widgets

    # These (and possibly others) can't default to any color since that would generate
    # color-setting sequences in the terminal. It's better to have them nilable, in which
    # case no sequences get generated and term's default is used. That's also how Blessed
    # does it.
    property fg : String?
    property bg : String?

    property bold : Bool = false
    property underline : Bool = false
    property blink : Bool = false
    property inverse : Bool = false
    property invisible : Bool = false
    property alpha : Float64? = nil

    property tab_size = 4

    # NOTE: Eventually reduce/streamline these
    property char : Char = ' '  # Generic char
    property pchar : Char = ' ' # Percent char
    property fchar : Char = ' ' # Foreground char
    property bchar : Char = ' ' # Background char

    property? fill = true

    property? ignore_border : Bool = false # If true, it's rendered in place of the border

    # Each of the following subelements are separate and can be styled individually.
    # If any of them is not defined, it defaults to main/parent style.
    # Keep the list sorted alphabetically.
    # Names of subelements could be improved over time to be more clear.

    setter bar : Style?

    def bar
      @bar || self
    end

    setter blur : Style?

    def blur
      @blur || self
    end

    def border=(value)
      @border = Border.from value
    end

    getter border : Border?

    def padding=(value)
      @padding = Padding.from value
    end

    getter padding : Padding?

    def shadow=(value)
      @shadow = Shadow.from value
    end

    getter shadow : Shadow?

    setter cell : Style?

    def cell
      @cell || self
    end

    setter focus : Style?

    def focus
      @focus || self
    end

    setter header : Style?

    def header
      @header || self
    end

    setter hover : Style?

    def hover
      @hover || self
    end

    setter item : Style?

    def item
      @item || self
    end

    setter label : Style?

    def label
      @label || self
    end

    setter scrollbar : Style?

    def scrollbar
      @scrollbar || self
    end

    setter selected : Style?

    def selected
      @selected || self
    end

    setter track : Style?

    def track
      @track || self
    end

    def initialize(
      *,
      border = nil,
      padding = nil,
      shadow = nil,
      @scrollbar = @scrollbar,
      @focus = @focus,
      @hover = @hover,
      @track = @track,
      @bar = @bar,
      @selected = @selected,
      @item = @item,
      @header = @header,
      @cell = @cell,
      @label = @label,
      @fg = @fg,
      @bg = @bg,
      @bold = @bold,
      @underline = @underline,
      @blink = @blink,
      @inverse = @inverse,
      @invisible = @invisible,
      alpha = nil,
      @char = @char,
      @pchar = @pchar,
      @fchar = @fchar,
      @bchar = @bchar,
      @ignore_border = @ignore_border
    )
      alpha.try { |v| @alpha = v.is_a?(Bool) ? (v ? 0.5 : nil) : v }
      border.try { |v| self.border = Border.from(v) }
      padding.try { |v| self.padding = Padding.from(v) }
      shadow.try { |v| self.shadow = Shadow.from(v) }
    end
  end

  # Type of border to draw.
  enum BorderType
    Bg   # Bg color
    Line # Line, drawn in ACS or Unicode chars
    # Dotted
    # Dashed
    # Solid
    # Double
    # DotDash
    # DotDotDash
    # Groove
    # Ridge
    # Inset
    # Outset
  end

  # Class for border definition.
  class Border
    property type = BorderType::Line

    property bg : String?
    property fg : String?

    property char = ' '
    # XXX There is some duplication between @style and these 5.
    # They must be present for sattr() to be able to work on the Border object.
    # But on the other hand, it allows these features which do not exist in Blessed.
    property bold : Bool = false
    property underline : Bool = false
    property blink : Bool = false
    property inverse : Bool = false
    property invisible : Bool = false

    property left = 1
    property top = 1
    property right = 1
    property bottom = 1

    def self.from(value)
      case value
      in true
        Border.new
      in nil, false
        nil
      in BorderType
        Border.new value
      in Border
        value
      in Int
        Border.new value, value, value, value
      end
    end

    def initialize(
      @type = @type,
      @bg = @bg,
      @fg = @fg,
      @left = @left,
      @top = @top,
      @right = @right,
      @bottom = @bottom
    )
    end

    def initialize(all : Int)
      @left = @top = @right = @bottom = all
    end

    def initialize(@left : Int, @top : Int, @right : Int, @bottom : Int)
    end

    def adjust(pos, sign = 1)
      pos.xi += sign * @left
      pos.xl -= sign * @right
      pos.yi += sign * @top
      pos.yl -= sign * @bottom
      pos
    end

    # XXX enable these two after -Dpreview_overload_order becomes the default
    # def initialize(left_and_right, top_and_bottom)
    #  @left = @right = left_and_right
    #  @top = @bottom = top_and_bottom
    # end

    # def initialize(all : Bool = true)
    #  @left = @top = @right = @bottom = all
    # end

    # Disabled since nothing uses it for now:
    # def any?
    #  !!(@left || @top || @right || @bottom)
    # end
  end

  # Class for padding definition.
  #
  # NOTE "Padding" as in spacing around elements. Same order as in HTML (ltrb)
  class Padding
    property left : Int32 = 0
    property top : Int32 = 0
    property right : Int32 = 0
    property bottom : Int32 = 0

    def self.from(value)
      case value
      in true
        Padding.new 1
      in nil, false
        nil
      in Padding
        value
      in Int
        Padding.new value, value, value, value
      end
    end

    def initialize(all : Int)
      @left = @top = @right = @bottom = all
    end

    def initialize(@left : Int, @top : Int, @right : Int, @bottom : Int)
    end

    def adjust(pos, sign = 1)
      pos.xi += sign * @left
      pos.xl -= sign * @right
      pos.yi += sign * @top
      pos.yl -= sign * @bottom
      pos
    end

    # def any?
    #  (@left + @top + @right + @bottom) > 0
    # end
  end

  # Class for shadow definition.
  class Shadow
    property left : Bool = false
    property top : Bool = false
    property right : Bool = true
    property bottom : Bool = true
    property alpha : Float64 = 0.5

    def initialize(
      @left = @left,
      @top = @top,
      @right = @right,
      @bottom = @bottom
    )
    end

    def self.from(value)
      case value
      in true
        Shadow.new true
      in nil, false
        nil
      in Shadow
        value
      in Float
        Shadow.new value
      end
    end

    def initialize(all : Int)
      @left = @top = @right = @bottom = all
    end

    def initialize(@alpha : Float64)
    end

    def initialize(@left : Int, @top : Int, @right : Int, @bottom : Int)
    end

    # adjust() for shadow isn't the same as for border/padding
    # def adjust(pos, sign = 1)
    #  pos.xi += sign * @left
    #  pos.xl -= sign * @right
    #  pos.yi += sign * @top
    #  pos.yl -= sign * @bottom
    #  pos
    # end
  end

  # class FocusEffects
  #  property bg
  # end

  # class HoverEffects
  #  property bg : String = "black"
  # end

  # Used to represent minimal widget position. It is returned from methods
  # that run calculations to determine that. *i fields are start positions,
  # *l methods are end positions.
  #
  # Used only internally; could be replaced by anything else that has
  # the necessary properties.
  struct Rectangle
    getter xi : Int32
    getter xl : Int32
    getter yi : Int32
    getter yl : Int32
    getter get : Bool

    # NOTE Don't remember the exact function of `get`. IIRC it goes to
    # recalculate from parent. Check what the function is and document
    # it here.
    def initialize(@xi, @xl, @yi, @yl, @get = false)
    end
  end

  # Helper class implementing only minimal position-related interface.
  # Used for holding widget's last rendered position.
  # XXX Could be renamed to LastRenderedPos[ition] for clarity.
  class LPos
    # TODO Can almost be replaced with a struct. Only minimal problems appear.
    # See tech-demo example, fix the issue and replace with struct.

    None = new

    # Starting cell on X axis
    property xi : Int32 = 0

    # Ending cell on X axis
    property xl : Int32 = 0

    # Starting cell on Y axis
    property yi : Int32 = 0

    # Endint cell on Y axis
    property yl : Int32 = 0

    property base : Int32 = 0

    # Informs us which side is partly hidden due to being enclosed in a
    # parent (and potentially scrollable) element.
    property? no_left : Bool = false
    property? no_right : Bool = false
    property? no_top : Bool = false
    property? no_bottom : Bool = false

    # Number of times object was rendered
    property renders = 0

    property aleft : Int32? = nil
    property atop : Int32? = nil
    property aright : Int32? = nil
    property abottom : Int32? = nil
    property awidth : Int32? = nil
    property aheight : Int32? = nil

    # These should be allowed to be just 0 because I'd think their offsets
    # are already included in a* properties.
    # (XXX Verify that and fix; seems like an inconsistency in logic if that
    # sentence/description is true.
    property ileft : Int32 = 0
    property itop : Int32 = 0
    property iright : Int32 = 0
    property ibottom : Int32 = 0
    property iwidth : Int32 = 0
    property iheight : Int32 = 0

    property _scroll_bottom : Int32 = 0
    property _clean_sides : Bool = false

    def initialize(
      @xi = @xi,
      @xl = @xl,
      @yi = @yi,
      @yl = @yl,
      @base = @base,
      @no_left = @no_left,
      @no_right = @no_right,
      @no_top = @no_top,
      @no_bottom = @no_bottom,

      @renders = @renders,

      # Disable all this:
      @aleft = @aleft,
      @atop = @atop,
      @aright = @aright,
      @abottom = @abottom,
      @awidth = @awidth,
      @aheight = @aheight,

      @ileft = @ileft,
      @itop = @itop,
      @iright = @iright,
      @ibottom = @ibottom,
      @iwidth = @iwidth,
      @iheight = @iheight
    )
    end
  end
end
