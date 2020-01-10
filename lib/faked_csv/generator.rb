module FakedCSV
    class Generator
        attr_reader :config, :rows

        def initialize(config)
            @config = config
        end

        def headers
            @config.headers
        end

        def rows
            puts "transforming data to rows ..."
            return @rows unless @rows.nil?
            @rows = []
            (0...@config.row_count).each do |r|
                row = []
                @config.fields.each do |field|
                    row << field[:data][r]
                end
                @rows << row
            end
            @rows
        end

        def print_to(writer)
            writer.write(headers.join(",") + "\n") unless headers.empty?
            (0...@config.row_count).each do |r|
                @config.fields.each_with_index do |field, index|
                    suffix = (index == (@config.fields.size - 1)) ? '' : ','
                    writer.write("#{field[:data][r]}#{suffix}")
                end
                writer.write("\n")
            end
        end

        def generate
            puts "preparing values ..."
            prepare_values

            @config.fields.each do |field|
                puts "generating random data for #{field} ..."
                field[:data] = []

                # let's get some data!
                if field[:type] == :inc_int
                    puts "generating increment values ..."
                    i = field[:start]
                    @config.row_count.times do
                        field[:data] << i
                        i += field[:step]
                    end
                elsif field[:rotate].nil? || field[:type] == :fixed
                    # not rotating? or fixed values? generate random value each time
                    puts "calling generator ..."
                    index = 0
                    @config.row_count.times do
                        field[:data] << _random_value(field)
                        print '.' if index % 10000 == 0
                        index += 1
                    end
                    puts

                    # inject user values if given and not fixed type
                    puts "injecting values ..."
                    unless field[:type] == :fixed || field[:inject].nil?
                        _random_inject(field[:data], field[:inject])
                    end
                else
                    # rotating? pick from prepared values
                    puts "selecting data from rotation ..."
                    _random_distribution(@config.row_count, field[:values].size) do |i, j|
                        field[:data][i] = field[:values][j]
                    end
                end
            end
        end

        def prepare_values
            @config.fields.each do |field|
                puts "prepare value for #{field} ..."
                # if it's fixed values or no rotate
                # we don't want to prepare values for this field
                if [:inc_int, :fixed].include?(field[:type]) || field[:rotate].nil?
                    next
                end

                # we don't have enough integers for the rotate
                if field[:type] == :rand_int && field[:rotate] > field[:max] - field[:min] + 1
                    raise "rotate should not be greater than the size of the range"
                end

                values = {}
                # let's first inject all user values if given
                puts "injecting user values ..."
                unless field[:inject].nil?
                    field[:inject].each do |inj|
                        values[inj] = true
                        # truncate more inject values if we go over the rows count
                        break if values.size == @config.row_count
                    end
                end
                # then generate as many data as we need
                puts "looping to get enough values ..."
                _loop do
                    # we want to get <rotate> unique values. stop when we got enough
                    break if values.size >= field[:rotate]
                    v = _random_value(field)
                    values[v] = true
                end
                field[:values] = values.keys
            end
        end

        def _random_distribution(total, parts)
            raise "parts has to be greater than 0" unless parts > 0
            raise "parts should not be greater than total" if total < parts
            cuts = {}
            _loop do
                break if cuts.size == parts - 1
                cuts[rand(total - 1)] = true
            end
            arr = []
            part_index = 0
            (0...total).each do |i|
                arr << part_index
                part_index += 1 if cuts.has_key? i
            end
            arr.shuffle.each_with_index do |v, i|
                yield(i, v)
            end
        end

        # inject <injects> into <values>
        def _random_inject(values, injects)
            used_indexes = {}
            count = injects.size > values.size ? values.size : injects.size
            (0...count).each do |i|
                inj = injects[i]
                times_inject = rand(values.size / injects.size / 10)
                times_inject = 1 if times_inject < 1
                times_inject.times do
                    rand_index = rand(values.size)
                    _loop do
                        break unless used_indexes.has_key? rand_index
                        rand_index = rand(values.size)
                    end
                    used_indexes[rand_index] = true
                    values[rand_index] = inj
                end
            end
        end

        def _random_value(field)
            case field[:type]
            when :rand_int
                return Generator.rand_int field[:min], field[:max]
            when :rand_float
                return Generator.rand_float field[:min], field[:max], field[:precision]
            when :rand_char
                if field[:format].nil?
                    return Generator.rand_char field[:length]
                else
                    return Generator.rand_formatted_char field[:format]
                end
            when :fixed
                return field[:values].sample
            else # faker
                return Generator.fake field[:type]
            end
        end

        def _loop
            max_attempts = 1000_000_000_000
            i = 0
            (0...max_attempts).each do |j|
                yield
                i += 1
            end
            raise "max attempts reached" if i == max_attempts
        end

        ## individual random generators

        def self.rand_char(length)
            o = [('a'..'z'), ('A'..'Z'), (0..9)].map { |i| i.to_a }.flatten
            string = (0...length).map { o[rand(o.length)] }.join
        end

        def self.rand_formatted_char(format)
            res = []
            i = 0
            while i < format.size
                case a = format[i]
                when '/'
                    i += 1
                    res << single_rand_char(format[i])
                else
                    res << a
                end
                i += 1
            end
            return res.join("")
        end

        def self.single_rand_char(format)
            aa = nil
            case format
            when 'W' # A-Z
                aa = ('A'..'Z').to_a
            when 'w' # a-z
                aa = ('a'..'z').to_a
            when 'd' # 0-9
                aa = (0..9).to_a
            when 'D' # A-Za-z
                aa = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
            when '@'
                aa = [('a'..'z'), ('A'..'Z'), (0..9)].map { |i| i.to_a }.flatten
            else
                raise "invalid format: #{format} in single_rand_char"
            end
            return aa[rand(aa.size)]
        end

        def self.rand_int(min, max)
            raise "min > max" if min > max
            min + rand(max - min + 1)
        end

        def self.rand_float(min, max, precision)
            raise "min > max" if min > max
            (rand * (max - min) + min).round(precision)
        end

        def self.fake(type)
            Fakerer.new(type).fake
        end
    end
end