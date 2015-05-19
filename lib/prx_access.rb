module PrxAccess
  def api
    HyperResource.new(root: cms_root)
  end

  def cms_root
    ENV['CMS_ROOT'] || 'https://cms.prx.org/api/vi/'
  end

  def prx_root
    ENV['PRX_ROOT'] || 'https://beta.prx.org/stories/'
  end
end
