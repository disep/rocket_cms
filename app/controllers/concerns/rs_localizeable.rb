module RsLocalizeable
  extend ActiveSupport::Concern
  included do
    before_action do
      I18n.locale = params[:locale] || I18n.default_locale
      Settings.ns_default = "main_#{I18n.locale}"
      Settings.ns_fallback = "main"
    end
  end

  private

  def default_url_options(options={})
    {locale: params[:locale]}
  end

  def nav_get_menu_items(type)
    pages = ::Menu.find(type.to_s).pages.enabled
    if RocketCMS.mongoid?
      pages = pages.where(:"name.#{I18n.locale}".exists => true)
    elsif RocketCMS.active_record?
      if defined?(JsonbTranslate)

        pages = pages.where(["(name_translations -> ?)::text != ''", I18n.locale])
      elsif defined?(HstoreTranslate)
        pages = pages.where(["EXIST(name_translations, ?) = TRUE AND name_translations -> ? != ''", I18n.locale, I18n.locale])
      end
    end
    pages.sorted.to_a
  end

  def nav_get_url(item)
    (params[:locale].blank? ? "" : "/#{params[:locale]}") + (item.redirect.blank? ? item.fullpath : item.redirect)
  end

  def find_seo_extra(path)
    r = path.gsub(/(\/ru|\/en)/, "")
    if r.blank?
      r = "/"
    end
    Page.enabled.where(fullpath: r).first
  end
end

