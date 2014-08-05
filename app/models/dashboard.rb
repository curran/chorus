module Dashboard
  def self.build(entity_type)
    case entity_type
      when SiteSnapshot::ENTITY_TYPE then SiteSnapshot
      else raise ApiValidationError.new(:entity_type, :invalid)
    end.new
  end
end
