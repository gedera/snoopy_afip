class Hash
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end unless method_defined?(:symbolize_keys!)

  def symbolize_keys
    dup.symbolize_keys!
  end unless method_defined?(:symbolize_keys)

  def underscore_keys!
    keys.each do |key|
      self[(key.underscore rescue key) || key] = delete(key)
    end
    self
  end unless method_defined?(:underscore_keys!)

  def underscore_keys
    dup.underscore_keys!
  end unless method_defined?(:underscore_keys)

  # Implement this method because only is supported by > Rails 4, so if you want use only ruby, this will help. :)
  def deep_symbolize_keys
    return self.reduce({}) do |memo, (k, v)|
      memo.tap { |m| m[k.to_sym] = (v.is_a?(Hash) || v.is_a?(Array)) ? v.deep_symbolize_keys : v }
    end if self.is_a? Hash
    return self.reduce([]) do |memo, v|
      memo << v.deep_symbolize_keys; memo
    end if self.is_a? Array
    self
  end unless method_defined?(:deep_symbolize_keys)
end
