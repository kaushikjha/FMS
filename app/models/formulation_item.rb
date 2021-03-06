class FormulationItem < ActiveRecord::Base
  include SoftDeletable

  UNIT_WEIGHT = 1

  belongs_to :formulation, :touch => true
  belongs_to :compound, :polymorphic => true
  has_many :constituent_ingredients, :class_name => 'FormulationIngredient'

  attr_accessor :compound_name

  validates :quantity, :presence => true, :numericality => { :greater_than => 0, :less_than => 1000 }
  validates :compound, :presence => true

  after_save :explode!

  acts_as_audited :associated_with => :formulation

  default_scope order(:id)
  scope :as_on, lambda { |date| where("formulation_items.created_at <= :date and (formulation_items.deleted_at is null or formulation_items.deleted_at > :date)", { :date => date }) }
  scope :current, lambda { as_on(Time.now + 1) }
  scope :active, where(:deleted_at => nil)

  def quantity_percentage
    quantity * 100.0 / formulation.total_quantity
  end

  def price_percentage
    price(:inr) * 100 / formulation.total_price(:inr)
  end

  def to_s
    [compound.to_s, "#{quantity} gms"].join(' - ')
  end

  def price(currency_code)
    #compound.unit_price(currency_code) * UNIT_WEIGHT
    constituent_ingredients.entries.sum{|i| i.price(currency_code)}
  end

  class << self
    def import_from_csv(file)
      CSV.read(file, :headers => true).each do |row|
        begin
          formulation_id = row['FragranceId'] || row['AccordId']
          formulation = Formulation.find_by_origin_formula_id!(formulation_id)
          params = {
            :compound => Ingredient.find_by_code(row['CompId']) || Accord.find_by_origin_formula_id!(row['CompId']),
            :quantity => row['CompQty']
          }
          formulation.items.create_or_update(params)
        rescue
          nil
        end
      end
    end

    def create_or_update(params)
      if item = where({ :compound_type => params[:compound].class.name, :compound_id => params[:compound].id}).first
        item.update_attributes! params
      else
        item = create! params
      end
      item
    end
  end

  def explode!
    constituent_ingredients.delete_all    
    if compound.is_a?(Ingredient)
      constituent_ingredients.create! :ingredient => compound, :quantity => quantity
    else
      compound.constituent_ingredients.each do |ci|
        constituent_ingredients.create! :ingredient => ci.ingredient, :quantity => (quantity / compound.net_weight) * ci.quantity
      end
    end
  end
end
