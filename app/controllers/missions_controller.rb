class MissionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :mission, through: :course

  before_filter :load_general_course_data, only: [:show, :index, :new, :edit, :access_denied, :stats]

  def index
    @is_new = {}
    @tags_map = {}
    @selected_tags = params[:tags]
    @display_columns = {}
    @course.mission_columns_display.each do |cp|
      @display_columns[cp.preferable_item.name] = cp.prefer_value
    end
    @time_format =  @course.mission_time_format

    @missions = @course.missions.accessible_by(current_ability).order(:open_at)
    @paging = @course.missions_paging_pref


    if @selected_tags
      tags = Tag.find(@selected_tags)
      mission_ids = tags.map { |tag| tag.missions.map{ |t| t.id } }.reduce(:&)
      @missions = @missions.find(mission_ids)
      tags.each { |tag| @tags_map[tag.id] = true }
    end

    if @paging.display?
      @missions = @selected_tags ? Kaminari.paginate_array(@missions).page(params[:page]).per(@paging.prefer_value.to_i) :
          @missions.page(params[:page]).per(@paging.prefer_value.to_i)
    end

    if curr_user_course.id
      unseen = @missions - curr_user_course.seen_missions
      unseen.each do |um|
        @is_new[um.id] = true
        curr_user_course.mark_as_seen(um)
      end
    end
    respond_to do |format|
      format.html # index.html.erb
    end
  end

  def show
    if curr_user_course.is_student?
      redirect_to course_missions_path
      return
    end
    @questions = @mission.get_all_questions
    @question = Question.new
    @question.max_grade = 10
    @coding_question = CodingQuestion.new
    @coding_question.max_grade = 10
    respond_to   do |format|
      format.html # show.html.erb
    end
  end

  def new
    @missions = @course.missions
    @mission.exp = 1000
    @mission.open_at = DateTime.now.beginning_of_day
    @mission.close_at = DateTime.now.end_of_day + 7  # 1 week from now

    @tags = @course.tags
    @asm_tags = {}

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def edit
    @missions = @course.missions
    @tags = @course.tags
    @asm_tags = {}
    @mission.asm_tags.each { |asm_tag| @asm_tags[asm_tag.tag_id] = true }
  end

  def create
    @missions = @course.missions
    @mission.pos = @course.missions.count + 1
    @mission.creator = current_user
    @mission.update_tags(params[:tags])
    if params[:files]
      @mission.attach_files(params[:files].values)
    end
    if  @mission.single_question?
      qn = params[:answer_type] == 'code' ? @mission.coding_questions.build : @mission.questions.build
      qn.max_grade = params[:max_grade]
    end

    respond_to do |format|
      if @mission.save
        @mission.update_grade
        @mission.schedule_mail(@course.user_courses, course_mission_url(@course, @mission))
        format.html { redirect_to course_mission_path(@course, @mission),
                                  notice: "The mission #{@mission.title} has been created." }
      else
        format.html { render action: "new" }
      end
    end
  end

  def update
    @mission.update_tags(params[:tags])

    respond_to do |format|
      if @mission.update_attributes(params[:mission])

        if @mission.single_question? && @mission.get_all_questions.count > 1
          flash[:error] = "Mission already have several questions, can't change the format."
          @mission.single_question = false
          @mission.save
        end
        update_single_question_type
        update_mission_max_grade

        @mission.schedule_mail(@course.user_courses, course_mission_url(@course, @mission))
        format.html { redirect_to course_mission_url(@course, @mission),
                                  notice: "The mission #{@mission.title} has been updated." }
      else
        format.html {redirect_to edit_course_mission_path(@course, @mission) }
      end
    end
  end

  def destroy
    @mission.destroy
    respond_to do |format|
      format.html { redirect_to course_missions_url,
                                notice: "The mission #{@mission.title} has been removed." }
    end
  end

  def update_mission_max_grade
    if @mission.single_question? && @mission.max_grade != params[:max_grade].to_i
      qn = @mission.get_all_questions.first
      qn.max_grade = params[:max_grade]
      qn.save
      @mission.update_grade
    end
  end

  def update_single_question_type
    puts "update single question"
    unless @mission.single_question?
      return
    end
    puts "get single question type"
    type = params[:answer_type] == 'code' ? CodingQuestion : Question
    previous_qn = @mission.get_all_questions.first
    if type != previous_qn.class
      if previous_qn
        previous_qn.destroy
      end
      qn = type == CodingQuestion ? @mission.coding_questions.build : @mission.questions.build
      qn.max_grade = params[:max_grade]
      @mission.save
      @mission.update_grade
    end
  end

  def stats
    #@mission
    @stats_paging = @course.missions_stats_paging_pref
    @submissions = @mission.submissions
    @stds_coures = @course.user_courses.student.where(is_phantom: false).sort_by {|uc| uc.user.name.downcase }
    @my_std_coures = curr_user_course.get_only_tut_stds.select { |uc| !uc.is_phantom? }

    if @stats_paging.display?
      @stds_coures = Kaminari.paginate_array(@stds_coures).page(params[:page]).per(@stats_paging.prefer_value.to_i)
    end
    @stds_coures_phantom = @course.user_courses.student.where(is_phantom: true).sort_by {|uc| uc.user.name.downcase }

  end

  def access_denied
    respond_to   do |format|
      format.html # show.html.erb
    end
  end
end