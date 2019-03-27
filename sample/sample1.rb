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

    #Create ContainerInfo
    conInfo = Griddb::ContainerInfo.new(Hash["name" => "col01",
                                             "column_info_array" => [["name", Griddb::Type::STRING],
                                                                     ["status", Griddb::Type::BOOL],
                                                                     ["count", Griddb::Type::LONG],
                                                                     ["lob", Griddb::Type::BLOB]],
                                             "type" => Griddb::ContainerType::COLLECTION,
                                             "row_key" => true])

    #Create Collection
    col = gridstore.put_container(conInfo)

    #Change auto commit mode to false
    col.set_auto_commit(false)

    #Set an index on the Row-key Column
    col.create_index(Hash["column_name" => "name", "index_type" => Griddb::IndexType::DEFAULT])

    #Set an index on the Column
    col.create_index(Hash["column_name" => "count", "index_type" => Griddb::IndexType::DEFAULT])

    #Create and set row data
    blob = [65, 66, 67, 68, 69, 70, 71, 72, 73, 74].pack("U*")

    update = true
    #Put row: RowKey is "name01"
    ret = col.put(["name01", false, 1, blob])
    #Remove row with RowKey "name01"
    col.remove("name01")

    #Put row: RowKey is "name02"
    col.put(["name02", false, 1, blob])
    col.commit()

    mlist = col.get("name02")
    puts mlist

    #Create normal query
    query = col.query("select *")

    #Execute query
    rs = query.fetch(update)
    while rs.has_next()
        data = rs.next()
        data[2] = data[2] + 1

        print "Person: name=#{data[0]} status=#{data[1]} count=#{data[2]} lob="
        p data[3].unpack("U*")

        #Update row
        rs.update(data)
    end
    #End transaction
    col.commit()
rescue Griddb::GSException => e
    for i in 0..e.get_error_stack_size()
        print "[#{i}]"
        print " #{e.get_error_code(i)}"
        print " #{e.get_location(i)}"
        print " #{e.get_message(i)}\n"
     end
    print "#{e.what()}\n"
end
