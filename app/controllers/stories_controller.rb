class StoriesController < ApplicationController
	include Pundit
	rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
	# This controller handles everything around stories
	# Because main page lies in app#index, this controller mostly do JSON and 
	# allow upload and download of stories and all related activity
	
	
	before_action :user_logged_in, only: [:create, :update, :destroy]
	before_action :check_story_owner, only: [:update, :destroy]

	def show
		if Story.exists?(params[:id])
			@story = Story.find(params[:id])
			authorize @story

			@data = {title: @story.title, data: @story.data, url_key: @story.id}.to_json
			@author = @story.data["editorData"]["authorName"]
			@title = @story.title
			

			respond_to do |format|
				format.html {  
					# building preview here 
                	@first_stitches_content = []
                	@first_options_content = []
                	finding_option(@story.data["stitches"][@story.data["initial"]], @first_stitches_content, @first_options_content)                 	            	
                }
				format.json
				format.ink { render "inking.html"	}
			end

		else
			# below id is created to pass to the failing view the id of what might be an oldinklewriter story
       		@id = params[:id]
        	
          	respond_to do |format|
				format.html { render "stories/not_found.html.erb" }
				format.json { render json: { message: "Oops like you searched for a non existing story. You may head to legacy app and check this address http://oldinklewriter.inklestudios.com/stories/#{@id}.json to retrieve your story. You can then import it into the new app"}, status: 404 }
				format.ink { render "stories/not_found.html.erb" }
			end
		end
	end


	def index
		if current_user.present?
			@stories = set_user.stories
			render json:  @stories.to_a , :status => 200	  		
  		else
  			render "stories/cannot_display_stories"
  		end
	end

	def update
		@story = Story.find(params[:id])
		
		if params[:data].present? and params[:title].present?
			@story.data = params[:data]
			@story.title = params[:title]
			@story.save			
			
			render json: { message: "ok" }, :status => 201
		else
			render json: {}, :status => 400
		end
		
	end


	def create		
		@story = set_user.stories.new(data: params[:data], title: params[:title])
		if @story.save
			render json: { title: @story.title, data: @story.data, url_key: @story.url_key }, :status => 201
		else
			render json: {}, :status => 400
		end		
	end

	def destroy 
		@story = Story.find(params[:id])
		if @story.destroy
			render json: { message: "ok" }, :status => 201
		else
			render json: {}, :status => 400
		end	
	end

	private 

	# The 4 methods below help to recursively build the story preview in show action

	def find_chain(current_stitch, story_diverts)
		current_stitch["content"].each do |elem|
			if elem.is_a?String 
				story_diverts << elem
			end
		end
	end

	def find_next_stitch(current_stitch)
		found = false

  		current_stitch["content"].each do |elem|
			if elem.is_a?Hash 
				if elem.has_key?("divert")
					found = @story.data["stitches"][elem["divert"]]	
				end
			end
		end
		return found
  	end	

  	def is_an_option(current_stitch, story_options)
  		found = false
  		answer = []
  		current_stitch["content"].each do |elem|
			if elem.is_a?Hash 
				if elem.has_key?("option")
					story_options << elem["option"]
					found = true												
				end
			end
		end
  	end

  	  		
  	def finding_option(current_stitch, story_diverts, story_options)
  		find_chain(current_stitch, story_diverts) 
  		is_an_option(current_stitch, story_options)   					
  		
		if find_next_stitch(current_stitch)  				
			finding_option(find_next_stitch(current_stitch), story_diverts, story_options)		
		end
  		
  	end 

	

	def user_logged_in
		unless current_user.present?
			redirect_to root_path
		end
	end

	def set_user
		return current_user				
	end

	def check_story_owner
		unless set_user.id == Story.find(params[:id]).user.id
	      	redirect_to "stories/not_story_owner"
	    end	    
	end

	def story_params
    	params.require(:story).permit(:data, :title)
  	end

  	def user_not_authorized(exception)
	    policy_name = exception.policy.class.to_s.underscore

	    flash[:flash_error] = t "#{policy_name}.#{exception.query}", scope: "pundit", default: :default
	    redirect_to root_path
	end

  		
  	
end
