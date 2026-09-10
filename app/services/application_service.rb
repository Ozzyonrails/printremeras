# Base class for every service object. Subclasses implement #call and return
# success(**data) or failure(errors, code:). Callers use `result.success?`,
# `result.errors`, and data accessors (`result.order`).
class ApplicationService
  class Result
    attr_reader :errors, :code, :data

    def initialize(success:, data: {}, errors: [], code: nil)
      @success = success
      @data = data
      @errors = Array(errors)
      @code = code
      data.each { |key, value| define_singleton_method(key) { value } }
    end

    def success? = @success
    def failure? = !@success
    def [](key) = data[key]
    def error_message = errors.join(", ")
  end

  def self.call(...)
    new(...).call
  end

  private

  def success(**data)
    Result.new(success: true, data: data)
  end

  def failure(errors, code: :invalid, **data)
    Result.new(success: false, errors: errors, code: code, data: data)
  end
end
