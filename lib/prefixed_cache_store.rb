# encoding: ascii
require 'forwardable'

# A caching store that will expire only the keys saved through it, by using a common prefix
# for the namespace and the version number that can be ratched up to "unlink" all the related keys.
# It assumes that the keys are being evicted automatically if they do not get used often.
class PrefixedCacheStore
  VERSION = '0.0.1'
  
  RETAIN_PREFIX_FOR_SECONDS = 10
  
  extend Forwardable
  
  attr_reader :prefix, :store
  
  def_delegators :@store, :silence?, 
    :silence, :silence!,
    :mute, :cleanup, 
    :logger, :logger=,
    :instrument=, :instrument
  
  def initialize(store, prefix = 'pfx')
    @store = store
    @prefix = prefix
  end
  
  def fetch(name, options=nil)
    if block_given?
      @store.fetch(prefix_key(name), options) { yield }
    else
      @store.fetch(prefix_key(name), options)
    end
  end

  def read(name, options=nil)
    @store.read(prefix_key(name), options)
  end

  def write(name, value, options=nil)
    @store.write(prefix_key(name), value, options)
  end

  def exist?(name, options=nil)
    @store.exist?(prefix_key(name), options)
  end

  def delete(name, options=nil)
    @store.delete(prefix_key(name), options)
  end

  # Reads multiple keys from the cache using a single call to the
  # servers for all keys. Keys must be Strings.
  def read_multi(*names)
    names.extract_options!
    prefixed_names = names.map{|e| prefix_key(e) }
    result = @store.read_multi(*prefixed_names)
    # Unprefix the keys received
    result.inject({}) do |memo, (prefixed_key, value)|
      memo.merge(unprefix_key(prefixed_key) => value)
    end
  end
  
  # Increment a cached value.
  def increment(name, amount = 1, options=nil)
    @store.increment(prefix_key(name), amount, options)
  end

  # Decrement a cached value.
  def decrement(name, amount = 1, options=nil)
    @store.decrement(prefix_key(name), amount, options)
  end

  # Clear this cache namespace.
  def clear(options=nil)
    bump_version! # First bump the version
    @last_prefix = nil # Then make sure the cached version number will not be used
    get_and_set_current_version
  end

  private
  
  def bump_version!
    key = [@prefix, "version"].join('-')
    @store.write(key, @store.read(key).to_i + 1) # Redis does not support increment() with ActiveSupport values
  end
  
  # If the version prefix was last seen not too long ago, reuse it without asking the backend
  # for it over and over. If it wasn't just fetch it as normally
  def get_and_set_current_version
    if @last_prefix && @last_seen && (Time.now.utc - @last_seen) < RETAIN_PREFIX_FOR_SECONDS
      @last_prefix
    else
      @last_seen = Time.now.utc
      @last_prefix = read_and_set_current_version_from_backend
      @last_prefix
    end
  end
  
  def read_and_set_current_version_from_backend
    key = [@prefix, "version"].join('-')
    @store.fetch(key) { 0 }
  end
  
  def prefix_key(key)
    current_version = get_and_set_current_version
    [@prefix, current_version, expanded_key(key)].join('-')
  end
  
  def unprefix_key(key)
    @prefix_removal_re ||= /^#{prefix}\-\d+\-/ # Memoize to not parse the regex all the time
    key.gsub(@prefix_removal_re, '')
  end
  
  # Expand key to be a consistent string value. Invoke +cache_key+ if
  # object responds to +cache_key+. Otherwise, to_param method will be
  # called. If the key is a Hash, then keys will be sorted alphabetically.
  # Picked from the Dalli store adapter (cant use that one because it is a private method)
  def expanded_key(key) # :nodoc:
    return key.cache_key.to_s if key.respond_to?(:cache_key)

    case key
    when Array
      if key.size > 1
        key = key.collect{|element| expanded_key(element)}
      else
        key = key.first
      end
    when Hash
      key = key.sort_by { |k,_| k.to_s }.collect{|k,v| "#{k}=#{v}"}
    end

    key = key.to_param
    if key.respond_to? :force_encoding
      key = key.dup
      key.force_encoding('binary')
    end
    key
  end

end
