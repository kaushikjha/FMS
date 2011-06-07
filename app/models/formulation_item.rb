class FormulationItem < ActiveRecord::Base
  include SoftDeletable

  belongs_to :formulation, :touch => true
  belongs_to :compound, :polymorphic => true

  attr_accessor :compound_name

  validates :quantity, :presence => true, :numericality => { :greater_than => 0, :less_than => 1000 }
  validates :compound, :presence => true

  acts_as_audited :associated_with => :formulation

  default_scope order(:id)
  scope :as_on, lambda { |date| where("formulation_items.created_at <= :date and (formulation_items.deleted_at is null or formulation_items.deleted_at > :date)", { :date => date }) }
  scope :current, lambda { as_on(Time.now + 1) }
  scope :active, where(:deleted_at => nil)

  def quantity_percentage
    quantity * 100.0 / formulation.total_quantity
  end

  def to_s
    [compound.to_s, "#{quantity} gms"].join(' - ')
  end

  class << self
    def import_from_csv(file)
      CSV.read(file, :headers => true).each do |row|
        begin
          fragrance = Fragrance.find_by_origin_formula_id!(row['FragranceId'])
          params = {
            :compound => Ingredient.find_by_code(row['CompId']) || Accord.find_by_origin_formula_id!(row['CompId']),
            :quantity => row['CompQty']
          }
          fragrance.items.create_or_update(params)
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


end
