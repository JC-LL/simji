class Integer
  def bit_range range
    if range.min.nil?
      low, high=range.last,range.first
    else
      low,high=range.first,range.last
    end
    if low>high
      low,high=high,low
    end
    len = high - low + 1
    self >> low & ~(-1 >> len << len)
  end

  def bits low, high
    if low>high
      low,high=high,low
    end
    len = high - low + 1
    self >> low & ~(-1 >> len << len)
  end

  alias :bit_field :bit_range
end
