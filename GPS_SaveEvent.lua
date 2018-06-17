GPS_SaveEvent = {};
  GPS_SaveEvent_mt = Class(GPS_SaveEvent, Event);
  
  InitEventClass(GPS_SaveEvent, "GPS_SaveEvent");
  
  function GPS_SaveEvent:emptyNew()
      local self = Event:new(GPS_SaveEvent_mt);
      return self;
  end;
  
  function GPS_SaveEvent:new(object, slot,x,z,dx,dz,w,o,n)
      local self = GPS_SaveEvent:emptyNew()
      self.slot = slot;
	  self.x = x;
	  self.z = z;
	  self.dx = dx;
	  self.dz = dz;
	  self.w = w;
	  self.o = o;
	  self.n = n;
	  
      self.object = object;
      return self;
  end;
  
  function GPS_SaveEvent:readStream(streamId, connection)
      local id = streamReadInt32(streamId);
      self.slot = streamReadUIntN(streamId, 8);
	  self.x = streamReadFloat32(streamId);
	  self.z = streamReadFloat32(streamId);
	  self.dx = streamReadFloat32(streamId);
	  self.dz = streamReadFloat32(streamId);
	  self.w = streamReadFloat32(streamId);
	  self.o = streamReadFloat32(streamId);
	  self.n = streamReadString(streamId);
      
	  
	  self.object = networkGetObject(id);
      self:run(connection);
  end;
  
  function GPS_SaveEvent:writeStream(streamId, connection)
      streamWriteInt32(streamId, networkGetObjectId(self.object));
	  streamWriteUIntN(streamId, self.slot, 8);
	  streamWriteFloat32(streamId, self.x);
	  streamWriteFloat32(streamId, self.z);
	  streamWriteFloat32(streamId, self.dx);
	  streamWriteFloat32(streamId, self.dz);
	  streamWriteFloat32(streamId, self.w);
	  streamWriteFloat32(streamId, self.o);
	  streamWriteString(streamId, self.n);

  end;
  
  function GPS_SaveEvent:run(connection)
	  
	  local storeTable = {};
	  storeTable.lhdX0 = self.dx;
	  storeTable.lhdZ0 = self.dz;
	  storeTable.lhX0 = self.x;
	  storeTable.lhZ0 = self.z;
	  storeTable.GPSWidth = self.w;
	  storeTable.GPS_LRoffset = self.o;
	  storeTable.GPS_slotName = self.n;
	  GPS:saveCourse(self.object, self.slot, storeTable, true)
	  
      if not connection:getIsServer() then
          g_server:broadcastEvent(GPS_SaveEvent:new(self.object, self.slot,self.x, self.z, self.dx, self.dz, self.w, self.o, self.n), nil, connection, self.object);
		  -- print("GPS_SaveEvent:run - g_server:broadcastEvent(GPS_SaveEvent:new(self.object = "..tostring(self.object)..", self.slot = "..tostring(self.slot))
      end;
  end;