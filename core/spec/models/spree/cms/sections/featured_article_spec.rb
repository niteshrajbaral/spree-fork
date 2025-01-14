require 'spec_helper'

describe Spree::Cms::Sections::FeaturedArticle, type: :model do
  let!(:store) { Spree::Store.default }
  let!(:homepage) { create(:cms_homepage, store: store) }

  it 'validates presence of name' do
    expect(described_class.new(name: nil, cms_page: homepage)).not_to be_valid
  end

  it 'validates presence of page' do
    expect(described_class.new(name: 'Got Name')).not_to be_valid
  end

  context 'when a new Featured Article section is created' do
    let!(:featured_article_section) { create(:cms_featured_article_section, cms_page: homepage) }

    it 'sets gutters to No Gutters' do
      section = Spree::CmsSection.find(featured_article_section.id)

      expect(section.settings[:gutters]).to eq('No Gutters')
    end

    it 'sets fit to Screen' do
      section = Spree::CmsSection.find(featured_article_section.id)

      expect(section.fit).to eq('Screen')
    end

    it 'sets linked_resource_type to Spree::Taxon' do
      section = Spree::CmsSection.find(featured_article_section.id)

      expect(section.linked_resource_type).to eq('Spree::Taxon')
    end

    it '#gutters? is false' do
      section = Spree::CmsSection.find(featured_article_section.id)

      expect(section.gutters?).to be false
    end

    it '#fullscreen? is true' do
      section = Spree::CmsSection.find(featured_article_section.id)

      expect(section.fullscreen?).to be true
    end
  end

  context 'when changing the link type' do
    let!(:featured_article_section) { create(:cms_featured_article_section, cms_page: homepage) }

    before do
      featured_article_section.update!(linked_resource_type: 'Spree::Product')
    end

    it 'resets the linked resource to nil' do
      section = Spree::CmsSection.find(featured_article_section.id)

      expect(section.linked_resource_id).to be nil
    end
  end
end
