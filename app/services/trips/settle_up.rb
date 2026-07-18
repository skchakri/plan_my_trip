module Trips
  # Turns a trip's expenses into per-person balances and the minimal set of
  # "who pays whom" transfers that settles the group. Pure arithmetic — no AI,
  # no external calls — so it's fully unit-testable.
  #
  #   Trips::SettleUp.new(trip).groups
  #   # => [ CurrencyGroup(currency: "USD", total_cents:, balances:, transfers:) ]
  #
  # Computed per currency (mixing currencies in one balance would be wrong).
  # Expenses whose payer was since deleted are counted in the total but skipped
  # from the balance math, so the transfers always reconcile to zero.
  class SettleUp
    Balance = Struct.new(:person, :paid_cents, :share_cents, :net_cents, keyword_init: true)
    Transfer = Struct.new(:from, :to, :amount_cents, keyword_init: true)
    CurrencyGroup = Struct.new(:currency, :total_cents, :balances, :transfers, keyword_init: true)

    def initialize(trip)
      @trip = trip
      @people = trip.people.to_a
      @people_by_id = @people.index_by { |p| p.id.to_s }
      @all_ids = @people.map { |p| p.id.to_s }
    end

    def groups
      @trip.expenses.kept.group_by(&:currency).sort.map do |currency, expenses|
        build_group(currency, expenses)
      end
    end

    def any?
      @trip.expenses.kept.exists?
    end

    private

    def build_group(currency, expenses)
      total = expenses.sum(&:amount_cents)
      paid = Hash.new(0)
      owed = Hash.new(0)

      expenses.each do |exp|
        payer_id = exp.paid_by_id&.to_s
        next unless payer_id && @people_by_id.key?(payer_id) # skip ghost payers

        paid[payer_id] += exp.amount_cents
        allocate_shares(exp).each { |pid, cents| owed[pid] += cents }
      end

      balances = @people.map do |person|
        pid = person.id.to_s
        Balance.new(person: person, paid_cents: paid[pid], share_cents: owed[pid],
                    net_cents: paid[pid] - owed[pid])
      end

      CurrencyGroup.new(currency: currency, total_cents: total, balances: balances,
                        transfers: minimal_transfers(balances))
    end

    # Split one expense's cents across its participants, distributing the
    # remainder cents to the first few so the parts sum exactly to the total.
    def allocate_shares(exp)
      ids = exp.split_person_ids(@all_ids).select { |pid| @people_by_id.key?(pid) }
      return {} if ids.empty?

      base, extra = exp.amount_cents.divmod(ids.size)
      ids.each_with_index.to_h { |pid, i| [ pid, base + (i < extra ? 1 : 0) ] }
    end

    # Greedy debt simplification: repeatedly settle the largest debtor against
    # the largest creditor. Produces at most (people - 1) transfers.
    def minimal_transfers(balances)
      debtors   = balances.select { |b| b.net_cents.negative? }.map { |b| [ b.person, -b.net_cents ] }
      creditors = balances.select { |b| b.net_cents.positive? }.map { |b| [ b.person, b.net_cents ] }
      transfers = []

      di = ci = 0
      while di < debtors.size && ci < creditors.size
        debtor, debt = debtors[di]
        creditor, credit = creditors[ci]
        pay = [ debt, credit ].min
        transfers << Transfer.new(from: debtor, to: creditor, amount_cents: pay) if pay.positive?

        debtors[di][1]   = debt - pay
        creditors[ci][1] = credit - pay
        di += 1 if debtors[di][1].zero?
        ci += 1 if creditors[ci][1].zero?
      end

      transfers
    end
  end
end
