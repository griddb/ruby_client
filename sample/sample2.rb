#!/bin/env ruby

$:.unshift File.dirname(__FILE__)
require 'griddb_ruby'
Griddb = Griddb_ruby
require 'time'

begin
    factory = Griddb::StoreFactory.get_instance()

    #Get GridStore object
    storeInfo = Hash["host" => ARGV[0], "port" => ARGV[1].to_i, "cluster_name" => ARGV[2],
                     "database" => "public", "username" => ARGV[3], "password" => ARGV[4]]
    gridstore = factory.get_store(storeInfo)

    #Create ContainerInfo
    conInfo = Griddb::ContainerInfo.new(Hash["name" => "point01",
                                             "column_info_array" => [["timestamp", Griddb::Type::TIMESTAMP],
                                                                     ["active", Griddb::Type::BOOL],
                                                                     ["voltage", Griddb::Type::DOUBLE]],
                                             "type" => Griddb::ContainerType::TIME_SERIES,
                                             "row_key" => true])

    #Create TimeSeries
    ts = gridstore.put_container(conInfo)

    now = Time.now.getutc
    ts.put([now, false, 100])

    #Create normal query for range of timestamp from 6 hours ago to now
    query = ts.query("select * where timestamp > TIMESTAMPADD(HOUR, NOW(), -6)")
    update = false #No lock for update
    rs = query.fetch(update)

    while rs.has_next()
        data = rs.next()
        timestamp = data[0]
        active = data[1]
        voltage = data[2]
        print "Time=#{timestamp} Active=#{active} Voltage=#{voltage}\n"
    end
rescue Griddb::GSException => e
    for i in 0..e.get_error_stack_size()
        print "[#{i}]"
        print " #{e.get_error_code(i)}"
        print " #{e.get_location(i)}"
        print " #{e.get_message(i)}\n"
    end
    print "#{e.what()}\n"
end
