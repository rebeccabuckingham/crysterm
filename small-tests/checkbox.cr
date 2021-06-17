require "../src/crysterm"

module Crysterm
  include Tput::Namespace
  include Widgets

  s = Screen.new ignore_locked: [Tput::Key::CtrlQ]

  st = Style.new(
    bg: "blue",
    focus: Style.new(
      bg: "red"
    )
  )

  c1 = Checkbox.new content: "Checkbox 1", left: 6, top: 0, style: st
  c2 = Checkbox.new content: "Checkbox 2", left: 6, top: 2, style: st
  c3 = Checkbox.new content: "Checkbox 3", left: 6, top: 4, style: st
  c4 = Checkbox.new content: "Checkbox 4", left: 6, top: 6, style: st

  s.append c1, c2, c3, c4

  s.on(Crysterm::Event::KeyPress) do |e|
    e.key.try do |k|
      case k
      when .tab?
        s.focus_next
      when .shift_tab?
        s.focus_prev
      when .ctrl_q?
        exit
      end
    end
  end

  s.display.exec
end
