module FakedCSV
    class Config
        attr_reader :config, :fields, :row_count

        def initialize(config)
            @config = config
        end

        def fields
            parse if @fields.nil? # parse first if not parsed yet
            @fields
        end

        def include_headers?
            !@config['include_headers'].nil? && @config['include_headers']
        end

        def headers
            fields.map{|f| f[:name]}
        end

        # prepare the json config and generate the fields
        def parse
            if @config["rows"].nil? || @config["rows"].to_i < 0
                @row_count = 100 # default value
            else
                @row_count = @config["rows"].to_i
            end

            @fields = []
            if @config["fields"].nil? || @config["fields"].empty?
                raise "need 'fields' in the config file and at least 1 field in it"
            end

            @config["fields"].each do |cfg|
                field = {}

                if cfg["name"].nil?
                    raise "field needs a name"
                end
                field[:name] = cfg["name"].to_s

                if cfg["type"].nil? || cfg["type"].empty?
                    raise "field needs a type"
                end
                field[:type] = cfg["type"].to_s

                unless cfg["inject"].nil? || cfg["inject"].empty? || !cfg["inject"].kind_of?(Array)
                    field[:inject] = cfg["inject"].uniq # get rid of duplicates
                end

                unless cfg["rotate"].nil?
                    field[:rotate] = _validate_rotate cfg["rotate"]
                end

                case field[:type]
                when /inc:int/i
                    field[:type] = :inc_int
                    field[:start] = cfg["start"].nil? ? 1 : cfg["start"].to_i
                    field[:step] = cfg["step"].nil? ? 1 : cfg["step"].to_i
                when /rand:int/i
                    field[:type] = :rand_int
                    if cfg["range"].nil?
                        # no range specified? use the default range: [0, 100]
                        field[:min], field[:max] = 0, 100
                    else
                        field[:min], field[:max] = _min_max cfg["range"]
                    end
                when /rand:float/i
                    field[:type] = :rand_float
                    if cfg["range"].nil?
                        # no range specified? use the default range: [0, 1]
                        field[:min], field[:max] = 0, 1
                    else
                        field[:min], field[:max] = _min_max cfg["range"]
                    end
                    field[:precision] = cfg["precision"].nil? ? 1 : cfg["precision"].to_i
                when /rand:char/i
                    field[:type] = :rand_char
                    field[:length] = cfg["length"].nil? ? 10 : cfg["length"]
                    field[:format] = cfg["format"]
                when /fixed/i
                    field[:type] = :fixed
                    raise "need values for fixed type" if cfg["values"].nil?
                    field[:values] = cfg["values"]
                when /faker:\S+/i
                    field[:type] = cfg["type"]
                else
                    raise "unsupported type: #{field[:type]}. supported types: #{_supported_types}"
                end

                fields << field
            end
        end

        def _supported_types
            ['rand:int', 'rand:float', 'rand:char', 'fixed', 'faker:<class>:<method>'].join ", "
        end

        def _min_max(range)
            unless range.kind_of?(Array) && range.size == 2
                raise "invalid range. should be like: [0, 100]"
            end
            if range[0] >= range[1]
                raise "invalid range. 1st is >= 2nd"
            end
            return range[0], range[1]
        end

        def _validate_rotate(rotate)
            if rotate.to_s.include? "rows/"
                div = rotate.split("/")[1].to_i
                r = @row_count / div
            else
                r = rotate.to_i
            end
            return r > @row_count ? @row_count : r
        end
    end
end