GPS_Event = {};
  GPS_Event_mt = Class(GPS_Event, Event);
  
  InitEventClass(GPS_Event, "GPS_Event");
  
  function GPS_Event:emptyNew()
      local self = Event:new(GPS_Event_mt);
      return self;
  end;
  
  
  function GPS_Event:new(object, x,z,dx,dz,w,o,aStop,aStopDis,aTurn,aTurnMin,aTurnDir,laneOff,autoInv)
      local self = GPS_Event:emptyNew()
      self.x = x;
	  self.z = z;
	  self.dx = dx;
	  self.dz = dz;
	  self.w = w;
	  self.o = o;
	  self.aStop = aStop;
	  self.aStopDis = aStopDis;
	  self.aTurn = aTurn;
	  self.aTurnMin = aTurnMin;
	  self.aTurnDir = aTurnDir;
	  self.laneOff = laneOff;
	  self.autoInv = autoInv;

      self.object = object;
      return self;
  end;
  
  function GPS_Event:readStream(streamId, connection)
      local id = streamReadInt32(streamId);
      self.x = streamReadFloat32(streamId);
	  self.z = streamReadFloat32(streamId);
	  self.dx = streamReadFloat32(streamId);
	  self.dz = streamReadFloat32(streamId);
	  self.w = streamReadFloat32(streamId);
	  self.o = streamReadFloat32(streamId);
      self.aStop = streamReadBool(streamId);
	  self.aStopDis = streamReadFloat32(streamId);
	  self.aTurn = streamReadBool(streamId);
	  self.aTurnMin = streamReadUIntN(streamId, 8);
	  self.aTurnDir = streamReadFloat32(streamId);
	  self.laneOff = streamReadFloat32(streamId);
	  self.autoInv = streamReadBool(streamId);
	  
	  self.object = networkGetObject(id);
      self:run(connection);
  end;
  
  function GPS_Event:writeStream(streamId, connection)
      streamWriteInt32(streamId, networkGetObjectId(self.object));
	  streamWriteFloat32(streamId, self.x);
	  streamWriteFloat32(streamId, self.z);
	  streamWriteFloat32(streamId, self.dx);
	  streamWriteFloat32(streamId, self.dz);
	  streamWriteFloat32(streamId, self.w);
	  streamWriteFloat32(streamId, self.o);
	  streamWriteBool(streamId, self.aStop);
	  streamWriteFloat32(streamId, self.aStopDis);
	  streamWriteBool(streamId, self.aTurn);
	  streamWriteUIntN(streamId, self.aTurnMin, 8);
	  streamWriteFloat32(streamId, self.aTurnDir);
	  streamWriteFloat32(streamId, self.laneOff);
	  streamWriteBool(streamId, self.autoInv);
  end;
  
  function GPS_Event:run(connection)
	  self.object.lhX0 = self.x;
	  self.object.lhZ0 = self.z;
	  self.object.lhdX0 = self.dx;
	  self.object.lhdZ0 = self.dz;
	  self.object.GPSWidth = self.w;
	  self.object.GPS_LRoffset = self.o;
	  
	  self.object.GPSautoStop = self.aStop;
	  self.object.GPSautoStopDistance = self.aStopDis;
	  self.object.GPSTurnInsteadOfAutoStop = self.aTurn;
	  self.object.GPSturningMinFreeLanes = self.aTurnMin;
	  self.object.GPSturningDirection = self.aTurnDir;
	  self.object.GPSlaneNoOffset = self.laneOff;
	  self.object.GPSturnOffset = self.autoInv;
	  
	  
	  
      if not connection:getIsServer() then
          g_server:broadcastEvent(GPS_Event:new(self.object, self.x, self.z, self.dx, self.dz, self.w, self.o,self.aStop,self.aStopDis,self.aTurn,self.aTurnMin,self.aTurnDir,self.laneOff,self.autoInv), nil, connection, self.object);
      end;
  end;