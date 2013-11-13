require 'snmp'

class Printer
    
    # Create a new instance of Printer by passing its IP address
    def initialize(ip)
        @ip = ip
    end

    # Return the IP address of the printer
    def get_ip
        return @ip
    end

    # Get the value of an SNMP OID
    def snmp_get(oid)
        SNMP::Manager.open(:host => @ip) do |manager|
            query = SNMP::ObjectId.new(oid)
            response = manager.get(query)
            response.each_varbind do |res|
                return res.value
            end
        end
    end

    # Walk the SNMP tree starting at the given OID
    def snmp_walk(oid)
        SNMP::Manager.open(:host => @ip) do |manager|
            query = SNMP::ObjectId.new(oid)
            ret = Array.new
            manager.walk(oid) { |vb| ret.push(vb.value) }
            return ret
        end
    end

    # Query the printer for its model number
    def get_model
        return snmp_get('1.3.6.1.2.1.25.3.2.1.3.1')
    end

    # Query the printer for its serial
    def get_serial
        return snmp_walk('1.3.6.1.2.1.43.5.1.1.17').at(0)
    end

    # Query the printer for its message
    def get_messages
        return snmp_walk('1.3.6.1.2.1.43.18.1.1.8').at(0)
    end

    # Query the printer for its pagecount
    def get_page_count
        return snmp_get('1.3.6.1.2.1.43.10.2.1.4.1.1')
    end

    # Query the printer for its display
    def get_display
        return snmp_walk('1.3.6.1.2.1.43.16.5.1.2.1').at(0)
    end

    # Query the printer for its status
    # The printer will return an integer which we convert
    # into a meaninful string
    def get_status
        case snmp_get('1.3.6.1.2.1.25.3.5.1.1.1')
        when 1
            return 'Other'
        when 3
            return 'Idle'
        when 4
            return 'Printing'
        when 5
            return 'Warmup'
        else
            return 'Unknown'
        end
    end

    # Returns an array of all device IDs
    def get_device_ids
        return snmp_walk('1.3.6.1.2.1.25.3.2.1.1')
    end

    # Returns the name and status of the specified device as a hash
    def get_device(id)
        
        # Get the device name
        name = snmp_get("1.3.6.1.2.1.25.3.2.1.3.#{id}")
        
        # Make the status human-readable
        case snmp_get("1.3.6.1.2.1.25.3.2.1.5.#{id}")
        when 1
            status = 'Unknown'
        when 2
            status = 'Running'
        when 3
            status = 'Warning'
        when 4
            status = 'Testing'
        when 5
            status = 'Down'
        else
            status = 'Unknown'
        end

        return {:name => name, :status => status}
    end

    # Returns an array of the results of get_device_status for all of the
    # printer's devices
    def get_devices
        devices = get_device_ids
        ret = Array.new
        devices.each do |device|
            ret.push(get_device(device))
        end
        return ret
    end

    def get_consumable(id)
        color = snmp_get("1.3.6.1.2.1.43.12.1.1.4.1.#{id}")
        level = snmp_get("1.3.6.1.2.1.43.11.1.1.9.1.#{id}")
        capacity = snmp_get("1.3.6.1.2.1.43.11.1.1.8.1.#{id}")
        percentage = Float(level) * 100 / Float(capacity)
        return {:color => color,
            :level => level,
            :capacity => capacity,
            :percentage => percentage}
    end

    def get_consumable_names
        return snmp_walk('1.3.6.1.2.1.43.11.1.1.6.1').each { |item| item.chop! }
    end

    def get_consumables
        consumables = get_consumable_names

        ret = Array.new

        consumables.length.times do |id|
            cons = get_consumable(id + 1)
            cons[:name] = consumables.at(id)
            ret.push(cons)
        end

        return ret
    end

    def get_trays
        trays = Array.new
        snmp_walk('1.3.6.1.2.1.43.8.2.1.10.1').length.times do |id|
            tray = id + 1
            name = snmp_get("1.3.6.1.2.1.43.8.2.1.13.1.#{tray}")

            rem = snmp_get("1.3.6.1.2.1.43.8.2.1.10.1.#{tray}")
            case rem
            when -3
                status = 'OK'
            when -2
                status = 'Unknown'
            when 0
                status = 'Empty'
            else
                status = "#{rem} sheets remaining"
            end

            feed_dim = snmp_get("1.3.6.1.2.1.43.8.2.1.4.1.#{tray}")
            xfeed_dim = snmp_get("1.3.6.1.2.1.43.8.2.1.5.1.#{tray}")
            dim_units = snmp_get("1.3.6.1.2.1.43.8.2.1.3.1.#{tray}")

            if Integer(dim_units) == 3
                feed_dim = Float(feed_dim) / 10000
                xfeed_dim = Float(xfeed_dim) / 10000
            elsif Integer(dim_units) == 4
                feed_dim = Float(feed_dim) * 0.0000393700787
                xfeed_dim = Float(xfeed_dim) * 0.0000393700787
            end

            capacity = snmp_get("1.3.6.1.2.1.43.8.2.1.9.1.#{tray}")

            trays.push({:name => name, :status => status, :y => feed_dim, :x => xfeed_dim, :capacity => capacity})
        end

        return trays
    end

    private :snmp_get, :snmp_walk
end
