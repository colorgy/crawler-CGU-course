require 'json'
require 'nokogiri'
require 'rest_client'
require 'uri'

post_url = "http://www.is.cgu.edu.tw/portal/DesktopDefault.aspx?tabid=61&tabindex=1"
base_url = "http://www.is.cgu.edu.tw/portal"
url = "http://www.is.cgu.edu.tw/portal/DesktopDefault.aspx?tabid=61&tabindex=1&PS=JkNOTT0gJlRNPTQw-3YiBAEJ3ULU%3d"

# r = RestClient.get post_url
# query_page = Nokogiri::HTML(r.to_s)
# view_state = query_page.css('input[name="__VIEWSTATE"]').first['value']
# view_state_generator = query_page.css('input[name="__VIEWSTATEGENERATOR"]').first['value']
# cookies = r.cookies

# begin
#   RestClient.post(
#     post_url,
#     {
#       "__VIEWSTATE" => view_state,
#       "__VIEWSTATEGENERATOR" => view_state_generator,
#       "_ctl1:departmentsList" => '-1',
#       "_ctl1:termsList" => '40',
#       "_ctl1:classID" => '-1',
#       "_ctl1:weekDay" => '-1',
#       "_ctl1:beginSection" => '-1',
#       "_ctl1:endSection" => '-1',
#       "_ctl1:fieldsList" => '-1',
#       "_ctl1:newSearch" => '搜尋 Search'
#     },
#     cookies: cookies

#   )
# rescue Exception => e
# end



puts "preparing course lists..."
# r = RestClient.get URI.encode(url)
# doc = Nokogiri::HTML(r.to_s)

f = File.open('courses_list.html')
doc = Nokogiri::HTML(f.read)

courses = []
# skip Table Header
doc.css('#_ctl2_myGrid tr')[1..-1].each_with_index do |row, index|
  print "#{index}, "
  row_nodes = row.css('td')

  # 讓我們拿些基本資料

  # semester should be ['103', '2']
  # deprecated, use year & term instead
  # semester = row_nodes[0].text.gsub(/\s+/,'').split('/')
  course_code = row_nodes[1].text.strip
  serial_no = row_nodes[2].text.strip
  department = row_nodes[3].text.strip
  grade = row_nodes[4].text.strip
  # course_title = row_nodes[5].children.first.children.first.text.strip
  # english_title = row_nodes.css('#_ctl2_myGrid__ctl2_eCourseName').text.strip
  detail_url = "#{row_nodes[5].css('a').first['href']}"
  # 啊，好想統一用 lecturer 啊。
  instructor = row_nodes[6].text.strip
  credits = row_nodes[7].text.strip

  required_img_url = "images/CourseCategory_1.gif"
  required = row_nodes[8].css('img').first['src'] == required_img_url

  # 來處理下課程時間，將在後半段處理 detail page 時再抓教室
  # 先初始化 array
  course_time_location = []
  # time_nodes_raw = ["二;四", "6-8;5-8"]
  time_nodes_raw = row_nodes[9].text.strip.split('/').map {|p| p.strip}
  days = time_nodes_raw.first.split(';')
  periods = time_nodes_raw.last.split(';')

  # 合併 array，結果長這樣
  # course_time_location = [
  #   ["二", "6-8"],
  #   ["四, "5-8"]
  # ]
  (0..days.length-1).each do |i|
    a = []
    course_time_location << (a << days[i] << periods[i])
  end

  # 當前選課人數與人數上限
  # seats_raw = ["0", "90"]
  seats_raw = row_nodes[10].text.strip.split('/').map {|p| p.strip}
  enrollee = seats_raw.first
  seats = seats_raw.last



  # --------------------------------------------------------------
  print "好，開始爬 detail 頁面, #{detail_url}."
  r = RestClient.get(detail_url)
  doc = Nokogiri::HTML(r.to_s)
  print "done\n"

  # 覆寫一些資料算了
  # 學年 / 學期 / 年級 / 班別 / 開課單位 / 開課序號 / 主要開課序號 / 課程名稱 / 修課人數...
  year = doc.css('#CourseDetail1_year').text.strip
  if year == ""
    # 一個 DDOS 的概念
    redo
  end
  term = doc.css('#CourseDetail1_term').text.strip
  grade = doc.css('#CourseDetail1_classID').text.strip
  group_id = doc.css('#CourseDetail1_groupID').text.strip
  department = doc.css('#CourseDetail1_department').text.strip
  master_section_id = doc.css('#CourseDetail1_masterSectionID').text.strip
  course_title = doc.css('#CourseDetail1_cSectionName').text.strip
  english_title = doc.css('#CourseDetail1_eSectionName').text.strip
  enrollee = doc.css('#CourseDetail1_currentEnrollee').text.strip
  max_enrollee = doc.css('#CourseDetail1_maxEnrollee').text.strip
  min_enrollee = doc.css('#CourseDetail1_minEnrollee').text.strip
  # 核心能力，wtf? / 備註
  if !doc.css('#CourseDetail1_epccLink').empty?
    core_capability_url = doc.css('#CourseDetail1_epccLink').first['href']
  end
  footnote = doc.css('#CourseDetail1_footnote').text.strip

  # 處理上課教室
  # 處理完應該要長這樣
  # course_time_location = [
  #   ["二", "6-8", "E0201", "每週上課"],
  #   ["四, "5-8", "E0201", "每週上課"]
  # ]
  if !doc.css('#CourseDetail1_sectionTimeGrid tr').empty?
    doc.css('#CourseDetail1_sectionTimeGrid tr')[1..-1].each_with_index do |row, i|
      course_time_location[i] << row.css('td')[3].text.strip << row.css('td')[4].text.strip
    end
  end

  # 開始下面第二張表格
  table_outline = doc.css('#Table1').last
  if !table_outline.nil?
    website = table_outline.css('tr')[2].css('td').last.text.strip
  end

  textbook = doc.css('#CourseSyllabus1_courseBook').text.strip
  references = doc.css('#CourseSyllabus1_referenceBook').text.strip
  objective = doc.css('#CourseSyllabus1_objective').text.strip
  teaching_methods = doc.css('#CourseSyllabus1_pedagogy').text.strip
  description = doc.css('#CourseSyllabus1_cIntroduction').text.strip
  english_description = doc.css('#CourseSyllabus1_eIntroduction').text.strip
  grading = doc.css('#CourseSyllabus1_scoreMethod').text.strip
  office_hour = doc.css('#CourseSyllabus1_officeHour').text.strip

  # TODOs: 教學進度 / 先修課程
  # 要做終極詳細版的再做了，跳過！
  courses << {
    code: course_code,
    serial_no: serial_no,
    department: department,
    grade: grade,
    title: course_title,
    english_title: english_title,
    detail_url: detail_url,
    instructor: instructor,
    credits: credits,
    required: required,
    time_location: course_time_location,
    year: year,
    term: term,
    group_id: group_id,
    master_section_id: master_section_id,
    enrollee: enrollee,
    max_enrollee: max_enrollee,
    min_enrollee: min_enrollee,
    core_capability_url: core_capability_url,
    footnote: footnote,
    textbook: textbook,
    references: references,
    website: website,
    objective: objective,
    teaching_methods: teaching_methods,
    description: description,
    english_description: english_description,
    grading: grading,
    office_hour: office_hour
  }
end

File.open('courses.json', 'w') {|f| f.write(JSON.pretty_generate(courses))}
