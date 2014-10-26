## prefixed_cache_store

A cache wrapper for ActiveSupport that allows you to expire parts of your cache imperatively.

Sometimes you need to selectively nuke parts of your cache. All cache stores for Rails support the `Store#clear()`
method, but it usually nukes the entire backing store - be it memcached or Redis. This is mostly not what you expect.

This gem provides a wrapper for any Store that will prefix the stored keys. The prefix will be memorized in a separate
cache value. This cache value is going to be set periodically to prevent it from expiring too early.

When you increase this prefix value, all of the keys going throigh the store are going to be modified as well - so new
versions of the values are going to be generated and saved to the store. Consider a simple example:

    store = PrefixedCacheStore.new(Rails.cache, "pfx") # Sets "pfx-version" to 0
    store.write("foo", "Hello!") # Writes "pfx-0/foo"
    store.read("foo") # Reads "pfx-0/foo"
    store.clear # Replaces "pfx-version" with 1, does not flush your entire 60 gigabyte cache cluster
    store.read("foo") # Reads "pfx-1/foo", which is not found now
    store.write("foo", "Different hello!") # Writes "pfx-1/foo"

The value of the prefixed `version` key will be cached in memory of the Ruby process for 10 seconds between refetches - so most
of page renders will incur no more than one `read()` call for that specific key. Any `Store` can be wrapped in this object,
to your liking.

The gem has been extensively tested in production with Rails 3.x but should work fine with Rails 4 as well.

## Contributing to prefixed_cache_store
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

== Copyright

Copyright (c) 2014 Julik Tarkhanov. See LICENSE.txt for
further details.

