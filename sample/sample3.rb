#!/bin/env ruby

$:.unshift File.dirname(__FILE__)
require 'griddb_ruby'
Griddb = Griddb_ruby

begin
    factory = Griddb::StoreFactory.get_instance()

    #Get GridStore object
    storeInfo = Hash["host" => ARGV[0], "port" => ARGV[1].to_i, "cluster_name" => ARGV[2],
                     "database" => "public", "username" => ARGV[3], "password" => ARGV[4]]
    gridstore = factory.get_store(storeInfo)

    #Get TimeSeries
    #Reuse TimeSeries and data from sample 2
    ts = gridstore.get_container("point01")

    #Create normal query to get all row where active = FAlSE and voltage > 50
    update = false #No lock for update
    query = ts.query("select * from point01 where not active and voltage > 50")
    rs = query.fetch(update)

    #Get result
    while rs.has_next()
        data = rs.next()
        timestamp = (1000 * data[0].to_f).to_i

        #Perform aggregation query to get average value
        #during 10 minutes later and 10 minutes earlier from this point
        aggCommand = "select AVG(voltage) from point01 where timestamp > TIMESTAMPADD(MINUTE, TO_TIMESTAMP_MS(#{timestamp}), -10) AND timestamp < TIMESTAMPADD(MINUTE, TO_TIMESTAMP_MS(#{timestamp}), 10)"
        aggQuery = ts.query(aggCommand)
        aggRs = aggQuery.fetch()
        while aggRs.has_next()
            #Get aggregation result
            aggResult = aggRs.next()
            #Convert result to double and print out
            print "[Timestamp=#{timestamp}] Average voltage = #{aggResult.get(Griddb::Type::DOUBLE)}\n"
        end
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
