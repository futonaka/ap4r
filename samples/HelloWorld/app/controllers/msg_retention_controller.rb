class MsgRetentionController < ApplicationController

  RETENTION_STATUS = {}

  def retention_status_by_gruff

    interval = 5
    max_range = 6

    g = Gruff::Area.new 600
    g.theme_keynote
    g.title = "Message retension"
    g.minimum_value = 0
    g.maximum_value = 100

    g.labels = {}
    current_time = Time.now.to_i
    max_range.times do |r|
      g.labels[max_range-r-1] = Time.at(current_time-(max_range-r-1)*interval).strftime("%X")
    end

    ap4rs = []
    qms = Ap4rGroup::Default.map{|n, qm| [n, qm]}
    qms.each{|on| ap4rs << on[0]}

    #キューごとの平均未処理数を計算
    ap4rs.each do |on|
      qms.each do |n, qm|
        if(n == on && qm != nil) then
          qm.retention.data.each do |qn, stat|
            stat.each do |time, num|
              max_range.times do |r|
                from_time =current_time-(max_range-r)*interval
                to_time = current_time-(max_range-r-1)*interval
                if(time.to_i>from_time && time.to_i<=to_time) then
                  calc_average(on, qn, r, num)
                end
              end
            end
          end
        end
      end
    end

    #キューごとの平均未処理数を加算
    RETENTION_STATUS.each do |on, qs|
      _rs = Hash.new
      qs.each do |q,rs|
        rs.each do |r,ave|
          if(_rs.key?(r) && ((_ave=_rs.fetch(r))!=nil)) then
            _ave=_ave+ave[0]
          else
            _ave=ave[0]
          end
          _rs.store(r,_ave)
        end
      end
      qs.store(:'summary',_rs)
    end

    RETENTION_STATUS.each do |on, qs|
      sorted_num = Array.new
      max_range.times do |r|
        sorted_num << qs[:summary][r]
      end
      g.data(on, sorted_num)
    end

    send_data(g.to_blob,# :filename => "retention_#{Time.now.to_i}.png",
      :type => 'image/png', :disposition => 'inline')
  end


  def calc_average(oname, qname, range, num)

    if(RETENTION_STATUS.key?(oname) && (qs=RETENTION_STATUS.fetch(oname)) != nil) then
      if(qs.key?(qname) && (rs=qs.fetch(qname)) != nil) then
        if(rs.key?(range) && (ave=rs.fetch(range)) != nil) then
          ave[0]=(ave[0]*ave[1]+num)/(ave[1]+1)
          ave[1]=ave[1]+1
        else
          ave = [0,0]
        end
        rs.store(range,ave)
      else
        ave = [0,0]
        rs = Hash.new
        rs.store(range,ave)
      end
      qs.store(qname,rs)
    else
      ave = [0,0]
      rs = Hash.new
      rs.store(range,ave)
      qs = Hash.new
      qs.store(qname, rs)
    end
    RETENTION_STATUS.store(oname,qs)
  end

end
