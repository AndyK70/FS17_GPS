GPS_DeleteEvent = {};
  GPS_DeleteEvent_mt = Class(GPS_DeleteEvent, Event);
  
  InitEventClass(GPS_DeleteEvent, "GPS_DeleteEvent");
  
  function GPS_DeleteEvent:emptyNew()
      local self = Event:new(GPS_DeleteEvent_mt);
      return self;
  end;
  
  function GPS_DeleteEvent:new(object, slot,x,z,dx,dz,w,o,n)
      local self = GPS_DeleteEvent:emptyNew()
      self.slot = slot;
	  
	  
      self.object = object;
      return self;
  end;
  
  function GPS_DeleteEvent:readStream(streamId, connection)
      local id = streamReadInt32(streamId);
      self.slot = streamReadUIntN(streamId, 8);
	  
      
	  
	  self.object = networkGetObject(id);
      self:run(connection);
  end;
  
  function GPS_DeleteEvent:writeStream(streamId, connection)
      streamWriteInt32(streamId, networkGetObjectId(self.object));
	  streamWriteUIntN(streamId, self.slot, 8);
  end;
  
  function GPS_DeleteEvent:run(connection)		
	  GPS:deleteCourse(self.object, self.slot, true);
      if not connection:getIsServer() then
          g_server:broadcastEvent(GPS_DeleteEvent:new(self.object, self.slot), nil, connection, self.object);
		  -- print("GPS_DeleteEvent:run - g_server:broadcastEvent(GPS_DeleteEvent:new(self.object = "..tostring(self.object)..", self.slot = "..tostring(self.slot))
      end;
  end;