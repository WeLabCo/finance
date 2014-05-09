require_relative 'decimal'
require_relative 'rates'

require 'bigdecimal'
require 'bigdecimal/newton'
include Newton

module Finance
  # Provides methods for working with cash flows (collections of transactions)
  # @api public
  class Cashflow
    include Enumerable
    # Base class for working with Newton's Method.
    # @api private
    class Function
      values = {
        eps: "1.0e-16",
        one: "1.0",
        two: "2.0",
        ten: "10.0",
        zero: "0.0"
        }

      values.each do |key, value|
        define_method key do
          BigDecimal.new value
        end
      end

      def initialize(transactions, function)
        @transactions = Finance::Cashflow.new(transactions)
        @function = function
      end

      def values(x)
        value = @transactions.send(@function, Flt::DecNum.new(x[0].to_s))
        [ BigDecimal.new(value.to_s) ]
      end
    end


    def initialize(cash_flows)
      @__cash_flows = Array(cash_flows)
    end

    # calculate the internal rate of return for a sequence of cash flows
    # @return [DecNum] the internal rate of return
    # @param [Numeric] Initial guess rate
    # @example
    #   Finance::Cashflow.new([-4000,1200,1410,1875,1050]).irr #=> 0.143
    # @see http://en.wikipedia.org/wiki/Internal_rate_of_return
    # @api public
    def irr(guess=nil)
      # Make sure we have a valid sequence of cash flows.
      positives, negatives = @__cash_flows.partition{ |i| i >= 0 }
      if positives.empty? || negatives.empty?
        raise ArgumentError, "Calculation does not converge."
      end

      func = Function.new(@__cash_flows, :npv)
      rate = guess.nil? ? [ func.one ] : [ guess.to_f ]
      nlsolve( func, rate )
      rate[0]
    end

    def sum
      @__cash_flows.inject(:+)
    end

    # calculate the net present value of a sequence of cash flows
    # @return [DecNum] the net present value
    # @param [Numeric] rate the discount rate to be applied
    # @example
    #   Finance::Cashflow.new([-100.0, 60, 60, 60]).npv(0.1) #=> 49.211
    # @see http://en.wikipedia.org/wiki/Net_present_value
    # @api public
    def npv(rate)
      cashflow = @__cash_flows.collect { |entry| Flt::DecNum.new(entry.to_s) }

      rate, total = Flt::DecNum.new(rate.to_s), Flt::DecNum.new(0.to_s)
      cashflow.each_with_index do |cashflow, index|
        total += cashflow / (1 + rate) ** index
      end

      total
    end

    # calculate the internal rate of return for a sequence of cash flows with dates
    # @param[Numeric] Initial guess rate
    # @return [Rate] the internal rate of return
    # @example
    #   @transactions = []
    #   @transactions << Transaction.new(-1000, :date => Time.new(1985,01,01))
    #   @transactions << Transaction.new(  600, :date => Time.new(1990,01,01))
    #   @transactions << Transaction.new(  600, :date => Time.new(1995,01,01))
    #   Finance::Cashflow.new(@transactions).xirr(0.6) #=> Rate("0.024851", :apr, :compounds => :annually)
    # @api public
    def xirr(guess=nil)
      # Make sure we have a valid sequence of cash flows.
      positives, negatives = @__cash_flows.partition{ |t| t.amount >= 0 }
      if positives.empty? || negatives.empty?
        raise ArgumentError, "Calculation does not converge."
      end

      func = Function.new(@__cash_flows, :xnpv)
      rate = guess.nil? ? [ func.one ] : [ guess.to_f ]
      nlsolve( func, rate )
      Rate.new(rate[0], :apr, :compounds => :annually)
    end

    # calculate the net present value of a sequence of cash flows
    # @return [DecNum]
    # @example
    #   @transactions = []
    #   @transactions << Transaction.new(-1000, :date => Time.new(1985,01,01))
    #   @transactions << Transaction.new(  600, :date => Time.new(1990,01,01))
    #   @transactions << Transaction.new(  600, :date => Time.new(1995,01,01))
    #   @transactions.xnpv(0.6).round(2) #=> -937.41
    # @api public
    def xnpv(rate)
      rate  = Flt::DecNum.new(rate.to_s)
      start = @__cash_flows[0].date

      @__cash_flows.inject(0) do |sum, t|
        n = t.amount / ( (1 + rate) ** ((t.date-start) / Flt::DecNum.new(31536000.to_s))) # 365 * 86400
        sum + n
      end
    end

    def each(&block)
      @__cash_flows.each { |cash_flow| block.call(cash_flow) }
    end

    def [](*args)
      cash_flows = @__cash_flows[*args]
      Finance::Cashflow.new(cash_flows)
    end
  end
end
