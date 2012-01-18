class Blog::Post < ActiveRecord::Base
  
  set_table_name :blog_posts

  # -- Attributes -----------------------------------------------------------
  attr_accessor :tag_names,
                :category_ids
  
  # -- Relationships --------------------------------------------------------
  has_many :comments, :dependent => :destroy
  has_many :taggings, :dependent => :destroy
  has_many :tags, :through => :taggings
  
  # -- Validations ----------------------------------------------------------
  validates :title, :slug, :year, :month, :content,
    :presence   => true
  validates :slug,
    :uniqueness => { :scope => [:year, :month] }
  
  # -- Scopes ---------------------------------------------------------------
  default_scope order('created_at DESC')
  
  scope :published, where(:is_published => true)
  scope :for_year, lambda { |year| 
    where(:year => year) 
  }
  scope :for_month, lambda { |month|
    where(:month => month)
  }
  scope :tagged_with, lambda { |tag|
    joins(:tags).where('blog_tags.name' => tag, 'blog_tags.is_category' => false)
  }
  scope :categorized_as, lambda { |tag|
    joins(:tags).where('blog_tags.name' => tag, 'blog_tags.is_category' => true)
  }
  
  # -- Callbacks ------------------------------------------------------------
  before_validation :set_slug,
                    :set_date
  after_save        :sync_tags,
                    :sync_categories
  
  # -- Instance Methods -----------------------------------------------------
  def tag_names(reload = false)
    @tag_names = nil if reload
    @tag_names ||= self.tags.tags.collect(&:name).join(', ')
  end
  
protected
  
  def set_slug
    self.slug ||= self.title.to_s.slugify
  end
  
  def set_date
    self.year   ||= Time.zone.now.year
    self.month  ||= Time.zone.now.month
  end
  
  def sync_tags
    return unless tag_names
    self.taggings.for_tags.destroy_all
    self.tag_names.split(',').map{ |t| t.strip }.uniq.each do |tag_name|
      self.tags << Blog::Tag.find_or_create_by_name(tag_name)
    end
  end
  
  def sync_categories
    (self.category_ids || {}).each do |category_id, flag|
      case flag.to_i
      when 1
        if category = Blog::Tag.categories.find_by_id(category_id)
          category.taggings.create(:post => self)
        end
      when 0
        self.taggings.for_categories.where(:tag_id => category_id).destroy_all
      end
    end
  end
  
end