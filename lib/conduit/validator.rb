module Conduit
  class Validator
    def self.numeric
      lambda do |input, _session|
        return true if input.match?(/^\d+(\.\d+)?$/)
        "Please enter a valid number"
      end
    end

    def self.greater_than(value)
      lambda do |input, _session|
        num = input.to_f
        return true if num > value
        "Must be greater than #{value}"
      end
    end

    def self.less_than(value)
      lambda do |input, _session|
        num = input.to_f
        return true if num < value
        "Must be less than #{value}"
      end
    end

    def self.min_length(length)
      lambda do |input, _session|
        return true if input.length >= length
        "Must be at least #{length} characters"
      end
    end

    def self.max_length(length)
      lambda do |input, _session|
        return true if input.length <= length
        "Must be at most #{length} characters"
      end
    end

    def self.matches(pattern, message = "Invalid format")
      lambda do |input, _session|
        return true if input.match?(pattern)
        message
      end
    end

    def self.in_range(min, max)
      lambda do |input, _session|
        num = input.to_f
        return true if num.between?(min, max)
        "Must be between #{min} and #{max}"
      end
    end
  end
end
