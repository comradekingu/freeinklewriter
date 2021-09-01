class Story < ApplicationRecord
	after_create :assign_url_key
	after_create :generate_privacy
	after_save :process_stats
	after_save :process_rating


	belongs_to :user
	has_one :story_stat, dependent: :destroy
	has_one :story_privacy, dependent: :destroy

	private

	def assign_url_key
		self.url_key = self.id
		self.save	
	end

	def generate_privacy
		self.build_story_privacy(user_private: false, flagged_for_privacy:false, admin_private: false)
		self.story_privacy.save
	end

	def process_stats
		unless self.story_stat.present? 
			self.build_story_stat				
		end

		stat_results = Stats::Story.new(self).stats	

		stat_results.each do |k,v|
			self.story_stat[k]=v
		end

		self.story_stat.save

	end

	def process_rating
		
		if self.story_stat.present?						
			ratings = Rating::S_m_l_rating.new(self).calc
			ratings.each do |k,v|
				self.story_stat[k]=v
			end
			self.story_stat.save
		end
		
	end

end
