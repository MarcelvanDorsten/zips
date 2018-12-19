class Zip
    include ActiveModel::Model
    
attr_accessor :id, :city, :state, :population
    
def to_s
    "#{@id}: #{@city}, #{@state}, pop=#{@population}"
end
    
# initialize for both Mongo and a Web hash
def initialize(params={})
    # switch between both internal and external views of id and population
    @id=params[:_id].nil? ? params[:id] : params[:_id]
    @city=params[:city]
    @state=params[:state]
    @population=params[:pop].nil? ? params[:population] : params[:pop]
end
        
# tells Rails whether tis instance is persisted
def persisted?
    !@id.nil
end
def created_at
    nil
end
def updated_at
    nil
end
    
# convenience method for access to client in console
def self.mongo_client
    Mongoid::Clients.default
end
    
# convenience method for access to zips collection
def self.collection
    self.mongo_client['zips']
end

# implement a find that returns a collection of documents as hashes
# Use initiale(hash) to express individual documemts as a class instance
# * prototype - query example for value equality
# * sort - hash expressing multi-term sort order
# * offset - document to start results
# * limit - number of documents to include   
def self.all(prototype={}, sort={:population=>1}, offset=0, limit=100)
    # map internal :population term to :pop document term
    tmp = {} # hash needs to stay in stable order provided
    sort.each {|k,v|
        k = k.to_sym==:population ? :pop : k.to_sym
        tmp[k] = v if [:city, :state, :pop].include?(k)
        }
    sort=tmp
    # convert to keys and then eliminate any properties not of interest
    prototype=prototype.symbolize_keys.slice(:city, :state) if !prototype.nil?
    
    Rails.logger.debug {"getting all zips, prototype=#{prototype}, sort=#{sort}, offset=#{offset}, limit=#{limit} "}
    
    result=collection.find(prototype)
    .projection({_id:true, city:true, state:true, pop:true})
    .sort(sort)
    .skip(offset)
    result=result.limit(limit) if !limit.nil?
    
    return result
end
    
# locate a specific document. Use initialize(hash) on the result to get in class instance form.
def self.find id
    Rails.logger.debug {"getting zip #{id}"}
    
    doc=collection.find(:_id=>id)
                .projection({_id:true, city:true, state:true, pop:true})
                .first
    return doc.nil? ? nil : Zip.new(doc)
end

# create a new document using the current instance    
def save
    Rails.logger.debug {"saving #{self}"}
    
    result=collection.insert_one(_id:@id, city:@city, state:@state, pop:@pop)
    @id=result.inserted_id
end
    
# updates the values for this instance
def update(updates)
    Rails.loggger.debug {"updating #{self} with #{updates}"}
    
    # map internal :population term to :pop document term
    updates[:pop]=updates[:population] if !updates[:population].nil?
    updates.slice!(:city, :state, :pop) if !updates.nil?
    
    self.class.collection
              .find(_id:@id)
              .update_one(:$set=>updates)
end
   
# remove the document associated with this instance form the DB
def destroy
    Rails.logger.debug {"destroying #{self}"}
    
    self.class.collection
              .find(_id:@id)
              .delete.one
end
    
end