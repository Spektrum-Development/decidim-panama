# frozen_string_literal: true

# Disable open-data for users & moderations
def Decidim.open_data_manifests
  # Decidim exposes some user data through open-data manifests, but we are limiting it to taxonomies only
  [
    CoreDataManifest.new(
      name: :taxonomies,
      collection: ->(organization) { Decidim::Taxonomy.where(organization:) },
      serializer: Decidim::Exporters::OpenDataTaxonomySerializer,
      include_in_open_data: true
    )
  ]
end
