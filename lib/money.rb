# Prices are integer ARS cents. One formatter for backend views and mails.
module Money
  module_function

  def format(cents, currency: "ARS")
    amount = cents.to_i / 100.0
    whole, frac = ("%.2f" % amount).split(".")
    whole = whole.reverse.scan(/\d{1,3}/).join(".").reverse
    "#{currency == 'ARS' ? '$' : currency + ' '}#{whole},#{frac}"
  end
end
