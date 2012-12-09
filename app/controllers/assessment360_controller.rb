#SNVP:::Controller has been modified for the E317-Assessment 360 project.
class Assessment360Controller < ApplicationController

  def index
    @courses = Course.find_all_by_instructor_id(session[:user].id)
  end

  def one_assignment_statistics
    @choice = params[:choice]
    @assignment = Assignment.find(params[:assignment_id])
    @participants = @assignment.get_participants
    @types = {'Metareview' => 'MetareviewResponseMap','Feedback' => 'FeedbackResponseMap','Teammate Reviews' => 'TeammateReviewResponseMap','Participant Review' => 'ParticipantReviewResponseMap','Team Review' => 'TeamReviewResponseMap'}

  end

  def one_course_statistics
    course_id = params[:course_id]
    @course = Course.find(course_id)
    @assignments = Assignment.find_all_by_course_id(@course)

    @types = {'Metareview' => 'MetareviewResponseMap','Feedback' => 'FeedbackResponseMap','Teammate Reviews' => 'TeammateReviewResponseMap','Participant Review' => 'ParticipantReviewResponseMap','Team Review' => 'TeamReviewResponseMap'}
  end

  def show_student_list
    @choice = params[:choice]
    @course = Course.find(params[:course_id])
    @assignments = Assignment.find_all_by_course_id(@course)

    flag = params[:flag]

    @allUsers = @course.get_course_participants
  end

  def one_course_all_assignments
    #@REVIEW_TYPES = ["ParticipantReviewResponseMap", "FeedbackResponseMap", "TeammateReviewResponseMap", "MetareviewResponseMap"]
    @REVIEW_TYPES = ["TeammateReviewResponseMap"]
    @course = Course.find_by_id(params[:course_id])
    @assignments = Assignment.find_all_by_course_id(@course)
    @assignments.reject! {|assignment| assignment.get_total_reviews_assigned_by_type(@REVIEW_TYPES.first) == 0 }

    @assignment_pie_charts = Hash.new
    @assignment_bar_charts = Hash.new
    @assignment_distribution  = Hash.new
    @num_reviews = Hash.new
    @total_review_size = Hash.new
    @total_submissions = Hash.new
    @reviews_by_type = Hash.new
    @num_reviews_assigned = Hash.new
    @review_progress = Hash.new{|h, k| h[k] = []}
    @num_review_day = Array.new
    @consolidated_graph_url = ""
    @progress = Hash.new{|h, k| h[k] = []}
    assignment_index=0
    max_of_all = 0
    @assignments.each do |assignment|
      # Pie Chart Data .....................................
      reviewed = assignment.get_percentage_reviews_completed()
      @num_reviews_assigned[assignment] = assignment.get_total_reviews_assigned()
      @num_reviews[assignment] = assignment.get_total_reviews_completed()
      @total_review_size[assignment] = assignment.get_total_review_size()
      @total_submissions[assignment] = assignment.get_total_submissions_per_assignment()
      @ALL_REVIEW_TYPES = ["ParticipantReviewResponseMap", "FeedbackResponseMap", "TeammateReviewResponseMap", "MetareviewResponseMap", "TeamReviewResponseMap"]
      @reviews_by_type[assignment] = assignment.get_number_of_reviews_by_type()
      pending = 100 - reviewed
      reviewed_msg = reviewed.to_s + "% reviewed"
      pending_msg = pending.to_s + "% pending"

      GoogleChart::PieChart.new('160x100'," ",false) do |pc|
        pc.data_encoding = :extended
        pc.data reviewed_msg, reviewed, '228b22' # want to write '20' responed
        pc.data pending_msg, pending, 'ff0000' # rest of the class

        # Pie Chart with labels
        pc.show_labels = false
        pc.show_legend = true
        @assignment_pie_charts[assignment] = (pc.to_url)
      end

      # bar chart data ................................

      @review_progress[assignment]=Array.new
      bar_1_data = Array.new
      bar_2_data = Array.new
      dates = Array.new
      date = assignment.created_at.to_datetime.to_date
      #p date
      day_index = 0
      loop_count = 0
      reviews_done = 0
      #p Date.today
      max1 = 0
      while ((date <=> Date.today) <= 0)
        reviews_done_on_date = assignment.get_total_reviews_completed_by_date(date)

        if reviews_done_on_date != 0 then
          reviews_done += reviews_done_on_date
          if reviews_done_on_date > max1
            max1 = reviews_done_on_date
          end
          @review_progress[assignment].push(reviews_done_on_date)
          @progress[assignment_index].push(reviews_done_on_date)
          dates.push(date.month.to_s + "-" + date.day.to_s)
          @num_review_day[day_index] = (day_index+1).to_s
          day_index += 1
          loop_count += 1
        end

        date = (date.to_datetime.advance(:days => 1)).to_date
      end

      if max_of_all < max1
        max_of_all = max1
      end
      color_1 = 'c53711'
      color_2 = '000000'
      min=0
      #max= assignment.get_total_reviews_assigned

      GoogleChart::BarChart.new("350x80", " ", :vertical, false) do |bc|
        bc.data "Review", @review_progress[assignment], color_1
        bc.axis :y, :positions => [min, max1], :range => [min,max1]
        bc.axis :x, :labels => @num_review_day
        bc.width_spacing_options :bar_width => 5, :bar_spacing => 2, :group_spacing => 10
        bc.show_legend = false
        bc.stacked = false
        bc.data_encoding = :extended
        bc.params.merge!({:chl => "Nov"})
        @assignment_bar_charts[assignment] = (bc.to_url)
      end

      # Histogram score distribution .......................
      bar_2_data = assignment.get_score_distribution
      color_2 = '4D89F9'
      min = 0
      max = 100
       p '======================='
      p bar_2_data
      GoogleChart::BarChart.new("130x100", " ", :vertical, false) do |bc|
        bc.data "Review", bar_2_data, color_2
        bc.axis :y, :positions => [0, bar_2_data.max], :range => [0, bar_2_data.max]
        bc.axis :x, :positions => [min, max], :range => [min,max]
        bc.width_spacing_options :bar_width => 1, :bar_spacing => 0, :group_spacing => 0
        bc.show_legend = false
        bc.stacked = false
        bc.data_encoding = :extended
        bc.params.merge!({:chl => "Nov"})
        @assignment_distribution[assignment] = (bc.to_url)
      end
      assignment_index += 1
    end

    #overall graph
    #color_1 = 'c53711'
    color_2 = ['0000ff', 'ff0000', '00ff00']
    min=0
    max=200
    count=1

    GoogleChart::BarChart.new("900x200", " ", :vertical, false) do |bc|
      #@review_progress.each do |assignment_progress|
        #bc.data "Assignment" , assignment_progress, color_2
        #count += 1
      #end

      i =0
      while i < assignment_index
        bc.data "Assignment "+(i+1).to_s , @progress[i], color_2[i]
        i += 1
      end

      #bc.data "Assignment", @progress[0], color_2
      bc.axis :y, :positions => [min, max_of_all], :range => [min,max_of_all]
      bc.axis :x, :labels => @num_review_day
      bc.width_spacing_options :bar_width => 5, :group_spacing => 2
      #bc.show_legend = false
      #bc.stacked = false
      #bc.data_encoding = :extended
      #bc.params.merge!({:chl => "Nov"})
      @consolidated_graph_url = (bc.to_url)
    end


  end


  def one_course_all_students
    @REVIEW_TYPES = ["ParticipantReviewResponseMap", "FeedbackResponseMap", "TeammateReviewResponseMap", "MetareviewResponseMap","TeamReviewResponseMap"]
    @course=Course.find_by_id(params[:course_id]);
    @course_assigned_reviews_count=0
    @unique_users=@course.get_course_participants

       @unique_users.each do |user|
          @course_assigned_reviews_count+=user.get_total_reviews_assigned
       end
    @course
    @unique_users
    @course_assigned_reviews_count
  end

  def one_student_all_assignments
   @REVIEW_TYPES = ["ParticipantReviewResponseMap", "FeedbackResponseMap", "TeammateReviewResponseMap", "MetareviewResponseMap","TeamReviewResponseMap"]
   @user=User.find(params[:user_id])
   @participants=Participant.find_all_by_user_id(params[:user_id])
    bar_1_data = @user.get_total_reviews_completed
    bar_2_data = params[:count]
    @contribution = (((bar_1_data).to_f)/((bar_2_data).to_f))*100
    puts("--contribution", @contribution.to_f)
    color_1 = 'c53711'
    color_2 = '0000ff'
    min=0
    max=100
    puts(bar_1_data)
    puts(bar_2_data)
    puts (bar_1_data).is_a? Integer
    puts (bar_2_data).is_a? Integer

    abc=GoogleChart::BarChart.new("800x100", "Bar Chart", :horizontal, false)
    abc.data " ", [100], 'ffffff'
    abc.data "Total no. of reviews completed by student", [bar_1_data], color_1
    abc.data "Total no. of reviews completed by class", [bar_2_data.to_i], color_2
    abc.axis :x, :range => [min,max]
    abc.show_legend = true
    abc.stacked = false
    abc.data_encoding = :extended
    puts abc
    @abc=abc.to_url
    #puts abc.to_url({:chm => "000000,0,0.1,0.11"})
    #abc.process_data()
    end


 def all_assignments_all_students
    @course = Course.find_by_id(params[:course_id])
    @assignments = Assignment.find_all_by_course_id(@course)
    @types = {'Metareview' => 'MetareviewResponseMap','Feedback' => 'FeedbackResponseMap','Teammate Reviews' => 'TeammateReviewResponseMap','Participant Review' => 'ParticipantReviewResponseMap','Team Review' => 'TeamReviewResponseMap'}
  end

  def one_assignment_all_students
    @assignment = Assignment.find_by_id(params[:assignment_id])
    @participants = @assignment.participants
    
    @bc = Hash.new
    @participants.each do |participant|
      @questionnaires = @assignment.questionnaires
      bar_1_data = [participant.get_average_score]
      color_1 = 'c53711'
      min = 0
      max = 100

      GoogleChart::BarChart.new("300x40", " ", :horizontal, false) do |bc|
        bc.data " ", [100], 'ffffff'
        bc.data "Student", bar_1_data, color_1
        bc.axis :x, :range => [min,max]
        bc.show_legend = false
        bc.stacked = false
        bc.data_encoding = :extended
        @bc[participant.user.id] = bc.to_url
      end
    end
  end

  def one_assignment_one_student
    @assignment = Assignment.find_by_id(params[:assignment_id])
    @participant = Participant.find_by_user_id(params[:user_id])
    @questionnaires = @assignment.questionnaires
    bar_1_data = [@participant.get_average_score]
    bar_2_data = [@assignment.get_average_score]
    color_1 = 'c53711'
    color_2 = '0000ff'
    min=0
    max=100

    GoogleChart::BarChart.new("300x80", " ", :horizontal, false) do |bc|
      bc.data " ", [100], 'ffffff'
      bc.data "Student", bar_1_data, color_1
      bc.data "Class Average", bar_2_data, color_2
      bc.axis :x, :range => [min,max]
      bc.show_legend = true
      bc.stacked = false
      bc.data_encoding = :extended
      @bc= bc.to_url
    end
  end

  def all_assignments_one_student

  end
 end
