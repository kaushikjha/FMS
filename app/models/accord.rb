class Accord < Formulation

  class << self
    def import_from_csv(file)
      CSV.read(file, :headers => true).each do |row|
        params = { :origin_formula_id => row['AccordId'], :name => row['AccordName'], :product_year => (row['DateEntry'].split('-').last.to_i + 2000) }
        create_or_update(params)
      end
    end
  end

end
