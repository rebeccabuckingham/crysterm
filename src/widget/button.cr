require "./input"

module Crysterm
  class Widget
    # Button element
    class Button < Input
      include EventHandler

      getter value = false

      def initialize(**input)
        super **input

        on(Crysterm::Event::KeyPress) do |e|
          if e.char == ' ' || e.key.try(&.==(::Tput::Key::Enter))
            e.accept!
            press
          end
        end

        on(Crysterm::Event::Click) do # |e|
        # e.accept!
          press
        end
        # end
      end

      def press
        focus
        @value = true
        emit Crysterm::Event::Press
        @value = false
      end
    end
  end
end
