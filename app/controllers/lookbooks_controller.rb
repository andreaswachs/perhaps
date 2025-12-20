if Rails.env.development?
  class LookbooksController < Lookbook::PreviewController
    layout "lookbooks"
  end
end
