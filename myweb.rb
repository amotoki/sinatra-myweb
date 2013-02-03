require 'rubygems'
require 'sinatra'
require 'json'
require 'uuidtools'

class Conflict < Exception; end
class NotFound < Exception; end

class Tenants
  def initialize
    @tenants = {}
  end

  def exist?(id)
    return @tenants.has_key?(id)
  end

  def add(tenant={})
    if tenant.has_key?('id')
      id = tenant['id']
      if exist?(id)
        raise Conflict
      end
    else
      id = UUIDTools::UUID.random_create.to_s
    end
    @tenants[id] = {:id => id}
    return @tenants[id]
  end

  def get(id)
    if exist?(id)
      return @tenants[id]
    else
      raise NotFound
    end
  end

  def list
    return @tenants.values
  end

  def delete(id)
    if exist?(id)
      @tenants.delete(id)
    else
      raise NotFound
    end
  end
end

class Networks
  def initialize(tenants)
    @networks = {}
    @tenants = tenants
  end

  def exist?(tenant_id, net_id)
    if (@networks.has_key?(tenant_id) and
        @networks[tenant_id].has_key?(net_id))
      return true
    else
      return false
    end
  end

  def add(tenant_id, net)
    if not @tenants.exist?(tenant_id) then
      raise NotFound
    end
    net_id = net['id']
    if exist?(tenant_id, net_id) then
      raise Conflict
    end
    if not net_id then
      net_id = UUIDTools::UUID.random_create.to_s
    end
    desc = net['description'] || ''
    if not @networks.has_key?(tenant_id) then
      @networks[tenant_id] = {}
    end
    @networks[tenant_id][net_id] = {'id' => net_id, 'description' => desc}
    return @networks[tenant_id][net_id]
  end

  def get(tenant_id, net_id)
    if not exist?(tenant_id, net_id)
      raise NotFound
    end
    return @networks[tenant_id][net_id]
  end

  def list(tenant_id)
    if not @tenants.exist?(tenant_id) then
      raise NotFound
    end
    nets = @networks[tenant_id]
    if not nets then
      nets = []
    end
    return nets
  end

  def list_all
    return @networks
  end

  def delete(tenant_id, net_id)
    if not exist?(tenant_id, net_id)
      raise NotFound
    end
    @networks[tenant_id].delete(net_id)
    if @networks[tenant_id].empty? then
      @networks.delete(tenant_id)
    end
  end
end

class Ports
  def initialize(tenants, networks)
    @ports = {}
    @tenants = tenants
    @networks = networks
  end

  def exist?(tenant_id, net_id, port_id)
    if (@ports.has_key?(tenant_id) and
        @ports[tenant_id].has_key?(net_id) and
        @ports[tenant_id][net_id].has_key?(port_id)) then
      return true
    else
      return false
    end
  end

  def add(tenant_id, net_id, port)
    if not @networks.exist?(tenant_id, net_id) then
      raise NotFound
    end
    port_id = port['id']
    if exist?(tenant_id, net_id, port_id) then
      raise Conflict
    end
    if not @ports[tenant_id] then
      @ports[tenant_id] = {}
    end
    if not @ports[tenant_id][net_id] then
      @ports[tenant_id][net_id] = {}
    end
    if not port_id then
      port_id = UUIDTools::UUID.random_create.to_s
    end
    desc = port['description'] || ''
    @ports[tenant_id][net_id][port_id] = {'id' => port_id, 'description' => desc}
    return @ports[tenant_id][net_id][port_id]
  end

  def list(tenant_id, net_id)
    if not @networks.exist?(tenant_id, net_id) then
      raise NotFound
    end
    if not @ports.has_key?(tenant_id) or not @ports[tenant_id].has_key?(net_id) then
      return []
    end
    return @ports[tenant_id][net_id]
  end

  def list_all
    return @ports
  end

  def get(tenant_id, net_id, port_id)
    if not exist?(tenant_id, net_id, port_id)
       raise NotFound
    end
    return @ports[tenant_id][net_id][port_id]
  end

  def delete(tenant_id, net_id, port_id)
    if not exist?(tenant_id, net_id, port_id)
      raise NotFound
    end
    @ports[tenant_id][net_id].delete(port_id)
    if @ports[tenant_id][net_id].empty? then
      @ports[tenant_id].delete(net_id)
    end
    if @ports[tenant_id].empty? then
      @ports.delete(tenant_id)
    end
  end
end

tenants = Tenants.new
networks = Networks.new(tenants)
ports = Ports.new(tenants, networks)

#-----------------------------------------------------------

post '/tenants' do
  request.body.rewind
  data = request.body.read
  print data, "\n"
  data = JSON.parse data
  begin
    return tenants.add(data).to_json
  rescue Conflict
    return 409
  end
end

get '/tenants' do
  tenants.list.to_json
end

get '/tenants/:tenant' do |t|
  begin
    tenants.get(t).to_json
  rescue NotFound
    return 404
  end
end

delete '/tenants/:tenant' do |t|
  begin
    tenants.delete(t)
    return 204
  rescue NotFound
    return 404
  end
end

#-----------------------------------------------------------

post '/tenants/:tenant/networks' do |t|
  request.body.rewind
  data = request.body.read
  print data, "\n"
  data = JSON.parse data
  begin
    networks.add(t, data).to_json
  rescue NotFound
    return 404
  rescue Conflict
    return 409
  end
end

get '/tenants/:tenant/networks' do |t|
  begin
    networks.list(t).to_json
  rescue NotFound
    return 404
  end
end

get '/tenants/:tenant/networks/:network' do |t, n|
  begin
    networks.get(t, n).to_json
  rescue NotFound
    return 404
  end
end

delete '/tenants/:tenant/networks/:network' do |t, n|
  begin
    networks.delete(t, n)
    return 204
  rescue NotFound
    return 404
  end
end

#-----------------------------------------------------------

post '/tenants/:tenant/networks/:network/ports' do |t, n|
  request.body.rewind
  data = request.body.read
  print data, "\n"
  data = JSON.parse data
  begin
    return ports.add(t, n, data).to_json
  rescue NotFound
    return 404
  rescue Conflict
    return 409
  end
end

get '/tenants/:tenant/networks/:network/ports' do |t, n|
  begin
    ports.list(t, n).to_json
  rescue NotFound
    return 404
  end
end

get '/tenants/:tenant/networks/:network/ports/:port' do |t, n, p|
  begin
    ports.get(t, n, p).to_json
  rescue NotFound
    return 404
  end
end

delete '/tenants/:tenant/networks/:network/ports/:port' do |t, n, p|
  begin
    ports.delete(t, n, p)
    return 204
  rescue NotFound
    return 404
  end
end

#-----------------------------------------------------------

get '/networks' do
  return networks.list_all.to_json
end

get '/ports' do
  return ports.list_all.to_json
end
