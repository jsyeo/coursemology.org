class TagGroupsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :tag_group, through: :course

  before_filter :load_general_course_data, only: [:new, :edit, :show, :index]

  def new
  end

  def edit
  end

  def create
    respond_to do |format|
      if @tag_group.save
        format.html { redirect_to course_tags_path(@course),
                      notice: "The tag group '#{@tag_group.name}' has been created." }
      else
        format.html { render action: "new" }
      end
    end
  end

  def update
    respond_to do |format|
      if @tag_group.update_attributes(params[:tag_group])
        format.html { redirect_to course_tags_path(@course),
                      notice: "The tag group '#{@tag_group.name}' has been updated." }
      else
        format.html { render action: "edit" }
      end
    end
  end
end
