module ExpensesHelper
  SYMBOLS = { "USD" => "$", "EUR" => "€", "GBP" => "£", "JPY" => "¥", "INR" => "₹" }.freeze

  # Format integer cents in a currency: "$1,234.56", "€12.00", or "9.50 CAD"
  # for codes without a well-known symbol.
  def money(cents, currency = "USD")
    currency = currency.to_s.upcase
    amount = cents.to_i / 100.0
    if (symbol = SYMBOLS[currency])
      number_to_currency(amount, unit: symbol)
    else
      "#{number_with_precision(amount, precision: 2, delimiter: ',')} #{currency}"
    end
  end
end
