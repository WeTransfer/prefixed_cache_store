require_relative 'spec_helper'
require 'active_support'

describe PrefixedCacheStore do
  describe 'instantiation' do
    it 'creates a store wrapping another without passing the prefix' do
      some_store = double('SomeStore')
      store = described_class.new(some_store)
      
      expect(store.store).to eq(some_store)
      expect(store.prefix).to eq('pfx')
    end
    it 'creates a store wrapping another with given the prefix' do
      some_store = double('SomeStore')
      store = described_class.new(some_store, 'translations')
      expect(store.store).to eq(some_store)
      expect(store.prefix).to eq('translations')
    end
  end
  
  describe 'delegated methods' do
    it 'get forwarded to the backing store' do
      method_names = [:silence?, :silence, :silence!,
        :mute, :cleanup, :logger, :logger=, :instrument=, :instrument,
        :namespace, :namespace=
      ]
      
      store_double = double('SomeStore') 
      subject = described_class.new(store_double)
      method_names.each do | method_name |
        expect(subject).to respond_to(method_name)
        expect(store_double).to receive(method_name).once
        subject.public_send(method_name)
      end
    end
  end
  
  describe 'fetch' do
    it 'fetches the key and saves it to the cache and it then exists?' do
      some_store = ActiveSupport::Cache::MemoryStore.new
      subject = described_class.new(some_store, 'pre')
      
      data = subject.fetch("record1") { 123 }
      expect(data).to eq(123)
      expect(subject.exist?('record1')).to eq(true)
      
      expect(some_store.read("pre-version")).to eq(0), "Should have initialized the version to 0"
      expect(some_store.read("pre-0-record1")).to eq(123), "Should have saved the prefixed value"
      expect(some_store.read("record1")).to be_nil, "Should not have saved the unprefixed key"
    end
  end
  
  describe 'write' do
    it 'writes the key with the prefix and it then exists?' do
      some_store = ActiveSupport::Cache::MemoryStore.new
      subject = described_class.new(some_store, 'pre')
      
      subject.write("record2", 456)
      expect(subject.exist?('record2')).to eq(true)
      
      expect(some_store.read("pre-version")).to eq(0)
      expect(some_store.read("pre-0-record2")).to eq(456)
    end
  end
  
  describe 'read' do
    it 'reads the prefixed key instead' do
      some_store = ActiveSupport::Cache::MemoryStore.new
      subject = described_class.new(some_store, 'pre')
      
      some_store.write('pre-version', 0)
      some_store.write('pre-0-record3', "Ola peoples!")
      
      expect(subject.read("record3")).to eq('Ola peoples!')
    end
  end
  
  describe 'read_multi' do
    it 'performs multi-reads' do
      some_store = ActiveSupport::Cache::MemoryStore.new
      subject = described_class.new(some_store, 'pre')
      expect(subject.current_version_number).to eq(0)
      
      subject.write('record1', 'John')
      subject.write('record2', 'Jake')
      subject.write('record3', 'Mary')
      
      expect(subject.read_multi('record1', 'record2', 'record3')).to eq({"record1"=>"John", "record2"=>"Jake", "record3"=>"Mary"})
      
      expect(some_store.read("pre-version")).to eq(0)
      expect(some_store.read("pre-0-record1")).to eq('John')
      expect(some_store.read("pre-0-record2")).to eq('Jake')
      expect(some_store.read("pre-0-record3")).to eq('Mary')
      
    end
  end
  
  describe 'clear' do
    it 'bumps the version' do
      some_store = ActiveSupport::Cache::MemoryStore.new
      subject = described_class.new(some_store, 'pre')
      
      expect(subject.current_version_number).to eq(0)
      
      subject.write('record1', 'John')
      expect(subject.read('record1')).to eq('John')
      
      expect(some_store.read("pre-version")).to eq(0)
      
      subject.clear
      
      expect(subject.read('record1')).to be_nil
      subject.write('record1', 'Jake')
      expect(subject.read('record1')).to eq('Jake')
      
      
      expect(subject.current_version_number).to eq(1)
      expect(some_store.read("pre-version")).to eq(1)
      expect(some_store.read("pre-0-record1")).to eq('John')
      expect(some_store.read("pre-1-record1")).to eq('Jake')
    end
  end
  
  describe 'current_version'do
    it 'caches the current value for 10 seconds' do
      some_store = ActiveSupport::Cache::MemoryStore.new
      expect(some_store).to receive(:fetch).with("pre-version").once { 4 }
      
      subject = described_class.new(some_store, 'pre')
      5.times { subject.read('record1') }
      
      some_seconds_after = Time.now + 11.seconds
      allow(Time).to receive(:now) { some_seconds_after }
      expect(some_store).to receive(:fetch).with("pre-version").once { 4 }
      subject.read('record1')
    end
    
  end
end
