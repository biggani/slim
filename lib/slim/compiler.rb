module Slim
  # Compiles Slim expressions into Temple::HTML expressions.
  # @api private
  class Compiler < Filter
    # Handle control expression `[:slim, :control, code, content]`
    #
    # @param [String] ruby code
    # @param [Array] content Temple expression
    # @return [Array] Compiled temple expression
    def on_slim_control(code, content)
      [:multi,
        [:code, code],
        compile(content)]
    end

    # Handle conditional comment expression
    # `[:slim, :conditional_comment, conditional, content]`
    #
    # @param [Array] content Temple expression
    # @return [Array] Compiled temple expression
    def on_slim_condcomment(condition, content)
      [:html, :comment, [:multi, [:static, "[#{condition}]>"], compile(content), [:static, '<![endif]']]]
    end

    # Handle output expression `[:slim, :output, escape, code, content]`
    #
    # @param [Boolean] escape Escape html
    # @param [String] code Ruby code
    # @param [Array] content Temple expression
    # @return [Array] Compiled temple expression
    def on_slim_output(escape, code, content)
      if empty_exp?(content)
        [:multi, [:escape, escape, [:dynamic, code]], content]
      else
        tmp = unique_name

        [:multi,
         # Capture the result of the code in a variable. We can't do
         # `[:dynamic, code]` because it's probably not a complete
         # expression (which is a requirement for Temple).
         [:block, "#{tmp} = #{code}",

          # Capture the content of a block in a separate buffer. This means
          # that `yield` will not output the content to the current buffer,
          # but rather return the output.
          #
          # The capturing can be disabled with the option :disable_capture.
          # Output code in the block writes directly to the output buffer then.
          # Rails handles this by replacing the output buffer for helpers.
          options[:disable_capture] ? compile(content) : [:capture, unique_name, compile(content)]],

         # Output the content.
         [:escape, escape, [:dynamic, tmp]]]
      end
    end

    # Handle attribute expression `[:slim, :attr, escape, code]`
    #
    # @param [Boolean] escape Escape html
    # @param [String] code Ruby code
    # @return [Array] Compiled temple expression
    def on_slim_attr(name, escape, code)
      value = case code
      when 'true'
        [:static, name]
      when 'false', 'nil'
        [:multi]
      else
        tmp = unique_name
        [:multi,
         [:code, "#{tmp} = #{code}"],
         [:case, tmp,
          ['true', [:static, name]],
          ['false, nil', [:multi]],
          [:else,
           [:escape, escape, [:dynamic,
            if delimiter = options[:attr_delimiter][name]
              "#{tmp}.respond_to?(:join) ? #{tmp}.flatten.compact.join(#{delimiter.inspect}) : #{tmp}"
            else
              tmp
            end
           ]]]]]
      end
      [:html, :attr, name, value]
    end

    # Handle splat expression `[:slim, ;splat, code]`
    #
    # @param [String] code Ruby code
    # @return [Array] Compiled temple expression
    def on_slim_splat(code)
      name, value = unique_name, unique_name
      code = options[:sort_attrs] ? "(#{code}).sort_by {|#{name},#{value}| #{name}.to_s }" : "(#{code})"
      [:block, "#{code}.each do |#{name},#{value}|",
       [:case, value,
        ['true',
         [:multi,
          [:static, ' '],
          [:dynamic, name],
          [:static, "=#{options[:attr_wrapper]}"],
          [:dynamic, name],
          [:static, options[:attr_wrapper]]]],
        ['false, nil', [:multi]],
        ["''",
         options[:remove_empty_attrs] ? [:multi] :
         [:multi,
          [:static, ' '],
          [:dynamic, name],
          [:static, "=#{options[:attr_wrapper]}#{options[:attr_wrapper]}"]]],
        [:else,
         [:multi,
          [:static, ' '],
          [:dynamic, name],
          [:static, "=#{options[:attr_wrapper]}"],
          [:escape, true, [:dynamic, value]],
          [:static, options[:attr_wrapper]]]]]]
    end
  end
end
