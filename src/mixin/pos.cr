module Crysterm
  module Mixin
    module Pos
      # Number of times object was rendered
      property renders = 0

      # Absolute left offset.
      property aleft : Int32? = nil

      # Absolute top offset.
      property atop : Int32? = nil

      # Absolute right offset.
      property aright : Int32? = nil

      # Absolute bottom offset.
      property abottom : Int32? = nil

      property? scrollable = false

      # Last rendered position
      property lpos : LPos? = nil
    end
  end
end