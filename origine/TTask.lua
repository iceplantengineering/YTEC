--元类:Metaclass
TTask = {data = {},
		 ctn = 0,
		 client = TClientHelper:new("led","127.0.0.1",28887)}

local xt = xshare.new('muthread share table')

guid_taskid = 0
function TTask:getTaskId()

	if(guid_taskid == 0) then
		local f = io.open("config\\taskid.txt","r")
		if(f) then
			local line = f:read()
			guid_taskid = tonumber(line)
			f:close()
		end
	end

	guid_taskid = guid_taskid +1

	local fs = io.open("config\\taskid.txt","w+")
	fs:write(tostring(guid_taskid))
	fs:close()

	return guid_taskid
end


function TTask:getTaskInfo(tid)
	if (not tid or tid == 0 ) then return nil, 0 end

	for k,v in pairs(self.data) do
		if(v.taskid == tid) then
	       	  return v,k
		end
	end
	return nil,0

end


function TTask:getTask(tno)
	if (not tno) then return nil, 0 end

	for k,v in pairs(self.data) do
		log("aaaaaaaabbeeeee",v.taskid)
		log("bbbbbbbbbbbbbbbecdd",v.taskno)
		if(v.taskno == tno) then
	       	  return v,k
		end
	end
	return nil,0

end


function TTask:new(sid)
	local obj = {}

	obj.sid = sid
	obj.taskno = sid
	obj.exstatus = 1
	obj.restatus = 0
	obj.reasonCode = 0
	obj.reason =""
	obj.sendno = 0

	obj.tempStation = 0
	obj.device = 0

	return obj
end


--解析接收的WMS任务
function TTask:createTask()
	
	
	local task = TRedis:rpop("taskInfo")
	
	if task and #task > 2 then
	    log("开始解析任务:",task)
		THelper:saveWmsLog("接收到WMS发送的信息",task)
		self:analysisTask(task)

	end
	

	local wcstask = TRedis:rpop("wcstask")
	if wcstask and #wcstask > 2 then
	    log("重发任务:",wcstask)
		THelper:saveWmsLog("接收到WCS发送的信息",wcstask)
		local pkt = cjson9.decode(wcstask) or {}
		local v,k = self:getTaskInfo(pkt.task_id)
		if k <= 0 or  v  then 
			table.insert(self.data,pkt)	
		else
			v.exstatus = pkt.exstatus	
			v.reason = pkt.reason
		end
	end

end



function TTask:analysisTask(task)
    --log(task)
	local pkt = cjson9.decode(task) or {}
	--logt(pkt)
	--log("1111111111111",pkt.cmd)
	if pkt.cmd and pkt.cmd > 100 and pkt.cmd <= 103 and pkt.task_id and pkt.task_id > 0 then
		--堆垛机任务	
		pkt.src_station = tonumber(pkt.src_station)
		pkt.dest_station = tonumber(pkt.dest_station)
		if pkt.cmd == 102 and pkt.dest_station and pkt.dest_station ~= 1004 then
			local num2 = math.ceil(pkt.dest_station)
			log("0000000000000",num2)
			local agv_d = {task_id = pkt.task_id,agv_dest = num2}
			local msg = cjson8.encode(agv_d)
			TRedis:lpush("agv_dests",msg)
			
			--pkt.dest_station = 1008
		end
		self:addTask(pkt)
	elseif pkt.cmd and pkt.cmd == 111 then
		--self:PostToLED(pkt)
	elseif pkt.cmd and pkt.cmd == 105 and pkt.type and pkt.task_id then
	    if pkt.st_request and (pkt.st_request == 1002 or pkt.st_request == 1004) then
		      local idc,info = self:getStationInfo(pkt.st_request-1);
			  if idc > 0  then
					info.requestY = 0
			  end
		end
	   
		 
		if (pkt.type == 0 and pkt.task_id > 0)
		then
			--强制完成任务	
			self:refreshWmsInfo(pkt.task_id, 6);			
		
		elseif (pkt.type == 1 and pkt.task_id > 0)
		then
			--取消任务
			self:refreshWmsInfo(pkt.task_id, 5);
			
		end
	elseif pkt.cmd and (pkt.cmd == 301 or pkt.cmd == 302 or pkt.cmd == 303 or pkt.cmd == 304) then
		local addrs = math.ceil(pkt.cmd) -  278
		local num1 = addrs * 10 + pkt.error_code
		TRedis:lpush("con_alarm",num1)	
	end

end


function TTask:addTask(task)

	local tid = task.task_id or 0
	local tk,cn = self:getTaskInfo(tid)
	if tk or cn > 0 then return nil end

	local ttype = 300
	local src = 0
	local dest = 0
	local smemo ="0"
	local dmemo= "0"
	local id1 = task.src_rack or 0
	local id2 = task.src_col or 0
	local id3 = task.src_row or 0
	
	local id4 = task.dest_rack or 0
	local id5 = task.dest_col or 0
	local id6 = task.dest_row or 0


	if (task.cmd == 101)
	then

		ttype = 100;
		if (task.src_station == 101)
		then
			src = 1001;

			--task.src_rack = 1;
			--task.src_col = 19;
			--task.src_row = 1;

			

		elseif (task.src_station == 102)
		then
			src = 1002;

			--task.src_rack = 2;
			--task.src_col = 19;
			--task.src_row = 1;

		elseif (task.src_station == 1002) then
			src = 1002;
		elseif (task.src_station == 1006) then
			src = 1006;
		end

		--id4 = task.dest_rack or 0;
		--id5 = task.dest_col or 0;
		--id6 = task.dest_row or 0;

		smemo = string.format("%d",src);
		dmemo = string.format("%d-%d-%d",task.dest_rack,task.dest_row,task.dest_col);
		--log(dmemo)


	elseif (task.cmd == 102)
	then
		ttype = 200;
		if (task.dest_station == 101)
		then
			dest = 1001;

			--task.dest_rack = 1;
			--task.dest_col = 19;
			--task.dest_row = 1;

			

		elseif (task.dest_station == 102)
		then
			dest = 1003;

			--task.dest_rack = 2;
			--task.dest_col = 19;
			--task.dest_row = 1;

			

		elseif (task.dest_station == 103) then
			dest = 1005;
		elseif (task.dest_station == 104) then
			dest = 1004;
		
		--elseif(task.dest_station >0 and task.dest_station < 10) then
		elseif (task.dest_station == 1004) then
			dest = 1004;
		elseif (task.dest_station == 1008) then
			dest = 1008;
		elseif(task.dest_station >0 and task.dest_station < 200) then
			dest = 1008 
		end 

		id1 = task.src_rack or 0;
		id2 = task.src_col or 0;
		id3 = task.src_row or 0;
		

		smemo = string.format("%d-%d-%d",task.src_rack,task.src_row,task.src_col);
		--log(smemo)
		dmemo = string.format("%d",dest);
	else
		return nil
	end

	local sid = self:getTaskId()
	local t = self:new(sid)

	t.cmd = task.cmd
	t.taskid = task.task_id
	t.srcStation = src
	t.destStation = dest
	t.taskType = ttype

	t.srcRack = id1
	t.srcCol = id2
	t.srcRow = id3

	t.destRack = id4
	t.destCol = id5
	t.destRow = id6

	t.srcMemo = smemo
	t.destMemo = dmemo
	t.goodsCode = "0"
	t.goodsCount = 1
	t.warehouse = 1

	t.barcode = task.barcode

    table.insert(self.data,t)
	THelper:saveWmsLog("WMS任务解析成功:",tid)
    --logt(t)
	
	local goods = string.format("'%s',%d,%d,%d,%d,%d,%d,%d,'%s','%s','%s',",t.goodsCode,t.goodsCount,t.srcRack,t.srcRow,t.srcCol,t.destRack,t.destRow,t.destCol,t.barcode,t.srcMemo,t.destMemo);
	
	local dt = os.time();
	local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
	t.createTime = st
	t.startTime = st
	t.alarm = 0
	
	
	local sql = string.format(" '%s','%d','%d','%d','%d','%d','%d','%d','%s','%s',1,0)",t.sid,t.cmd,t.taskid,t.taskno,t.taskType,t.srcStation,t.destStation,t.warehouse,st,st);
	
	local fel = "goods_code,goods_count,src_rack,src_row,src_col,dest_rack,dest_row,dest_col,barcode,src_memo,dest_memo,"
	sql = " INSERT INTO sys_task(" .. fel .. "sid,cmd,task_id,taskno,task_type,src_station,dest_station,warehouse,create_time,update_time,exstatus,restatus) values (" .. goods .. sql;
	
	TSQLiteHelper:updateCommand(sql);
	
	self:sendToRedis(t.taskid,t)
	
	

	return t


end



function TTask:sendToRedis(id,task)

	--TRedis:createRedisInfo("tasklist",id,task)
	if id%1000 == 0  then
		TRedis:clearOldHashFields("tasklist")
	end
	TRedis:hmset1("tasklist",task,id)
	
end


function TTask:checkInbound(code, item)

	local bb = 0;

	--int.TryParse(item.srcStation, out int src);
	local src = item.srcStation or 0
	local move = string.format("%d至%s",src,item.destMemo);
				
    ----------------------------------------------------------------
	
	if (item.destRack <= 0 or item.destCol <= 0 or item.destRow <= 0)
	then
		if (item.reasonCode ~= 21)
		then
			item.reason = "21|终点信息有误";
			self:refreshTaskReason(21, item);

			local ss = "终点信息有误";
			--self:addLedState(code, ss);
			---self:addLedMsg(code, item.taskid, move, item.barcode, ss, 100);
		end
		bb = 1;


	elseif (src <= 0)
	then
		if (item.reasonCode ~= 21)
		then
			item.reason = "21|起点信息有误";
			self:refreshTaskReason(21, item);

			--self:addLedState(code, "起点信息有误");
			local ss = "起点信息有误";
			---self:addLedMsg(code, item.taskid, move, item.barcode, ss, 100);
		end
		bb = 1;


	else
		if (code == 1101 and src == 1002)
		then
			item.tempStation = 1001;
			item.device = code;

		elseif (code == 1101 and src == 1006)
		then
			item.tempStation = 1005;
			item.device = code;


		else

			bb = 2;

		end
	
	end

	return bb == 0;
end


function TTask:checkOutbound(code, item)

	local bb = 0;
	
	--int.TryParse(item.destStation, out int dest);
	local dest = item.destStation or 0
	local move = string.format("%s至%d",item.srcMemo,dest)
	--------------------------------------------------------------
	if (item.srcRack <= 0 or item.srcCol <= 0 or item.srcRow <= 0)
	then
		if (item.reasonCode ~= 21)
		then
			item.reason = "21|起点信息有误";
			self:refreshTaskReason(21, item);

			local ss = "起点信息有误";
			--self:addLedState(code, ss);
			---self:addLedMsg(code, item.taskid, move, item.barcode, ss, 200);
		end
		bb = 1;

    --
	elseif (dest <= 0)
	then
		if (item.reasonCode ~= 21)
		then
			item.reason = "21|终点信息有误";
			self:refreshTaskReason(21, item);

			local ss = "终点信息有误";
			--self:addLedState(code, ss);
			---self:addLedMsg(code, item.taskid, move, item.barcode, ss, 200);
		end
		bb = 1;


	else

		if (code == 1101 and dest == 1001)
		then
			item.tempStation = 1002
			item.device = code;


		elseif (code == 1101 and dest == 1008)
		then
			item.tempStation = 1008
			item.device = code;


		elseif (code == 1102 and dest == 1005)
		then
			item.tempStation = 1006
			item.device = code;


		elseif (code == 1102 and dest == 1007)
		then
			item.tempStation = 1008
			item.device = code;
		
		elseif (code == 1101 and dest == 1004) then
			item.tempStation = 1004
			item.device = code
		elseif (code == 1101 and dest == 1008 )then
			item.tempStation = 1008
			item.device = code
		else

			bb = 1;

		end
	
	end

	return bb == 0;
end


----刷新堆垛机任务信息
function TTask:createCommand1(srm,tid,tno,ttype,srack,srow,scol,drack,drow,dcol,tsrc,tdest,ttemp)

	if (srm) then

		--local task = self.task
		local id = tid or 0
		local sn = tno or 0
		local tt = ttype or 0

		local ra1 = srack or 0;
		local co1 = scol or 0;
		local ro1 = srow or 0;

		local ra2 = drack or 0;
		local co2 = dcol or 0;
		local ro2 = drow or 0;

		local src = tsrc or 0
	    local dest = tdest or 0
		local temp = ttemp or 0

		if (tt >= 1 and sn > 0)
		then

			--单伸货叉堆垛机
			if (ra1 > 2 and ra1 % 2 == 0) then ra1 = 2 end
			if (ra1 > 2 and ra1 % 2 == 1) then ra1 = 1 end

			--单伸货叉堆垛机
			if (ra2 > 2 and ra2 % 2 == 0) then ra2 = 2 end
			if (ra2 > 2 and ra2 % 2 == 1) then ra2 = 1 end

		--	srm.TaskId = id
		--	srm.TaskNo = sn
		--	srm.TaskType = tt

		--	srm.DestStation = dest;
		--	srm.SrcRack = ra1;
		--	srm.SrcCol = co1;
		--	srm.SrcRow = ro1;

		--	srm.SrcStation = src;
		--	srm.DestRack = ra2;
		--	srm.DestCol = co2;
		--	srm.DestRow = ro2;

		--	srm.TempStation = temp
		
			srm.TaskId = id;
			srm.TaskNo = sn;
			srm.TaskType = tt;
			srm.WriteTaskType = tt;
			srm.WriteSrcStation = src;
			srm.WriteSrcRack = ra1;
			srm.WriteSrcCol = co1;
			srm.WriteSrcRow = ro1;
			srm.WriteDestStation = dest;
			srm.WriteDestRack = ra2;
			srm.WriteDestCol = co2;
			srm.WriteDestRow = ro2;
			srm.TempStation = temp;
			log("abcdefg",srm.TaskId,srm.TaskNo,srm.TaskType,srm.WriteTaskType,srm.WriteSrcStation,srm.WriteSrcRack,srm.WriteSrcCol,srm.WriteSrcRow,srm.WriteDestStation,srm.WriteDestRack,srm.WriteDestCol,srm.WriteDestRow,srm.TempStation)
			-- abcdefg,36041,20127,1,1,0,0,0,0,0,2,2,5,1002

		end

	end

end


function TTask:createCommand2(task,srm)

	if (srm and srm.TaskType and srm.TaskType == 0 and task) then

		--local task = self.task
		local id = task.taskid or "0"
		local sn = task.taskno or "0"
		local tt = task.taskType or 0

		local ra1 = task.srack or 0;
		local co1 = task.scol or 0;
		local ro1 = task.srow or 0;

		local ra2 = task.drack or 0;
		local co2 = task.dcol or 0;
		local ro2 = task.drow or 0;

		local src = t.srcStation or 0
	    local dest =t.destStation or 0

		if (tt >= 1 and #sn > 0)
		then

			--单伸货叉的堆垛机
			if (ra1 > 0 and ra1 % 2 == 0) then ra1 = 2 end

			--单伸货叉的堆垛机
			if (ra1 > 0 and ra2 % 2 == 0) then ra1 = 2 end

			srm.TaskId = id
			srm.TaskNo = sn
			srm.TaskType = tt

			srm.DestStation = dest;
			srm.SrcRack = ra1;
			srm.SrcCol = co1;
			srm.SrcRow = ro1;

			srm.SrcStation = src;
			srm.DestRack = ra2;
			srm.DestCol = co2;
			srm.DestRow = ro2;

		end

	end

end


--调度堆垛机任务
function TTask:exceutTask(srm)
	--local idx = 0
	--local task = nil
	local ss = ""

	if #self.data <= 0 then
	
		return  0,nil
	end
	
	self.ctn = self.ctn + 1;
	if self.ctn > 9000 then self.ctn = 2 end
	--堆垛机编号
	
	
    local code = srm.key or 0
	
	if code == 0 then return 0,nil end

	--任务执行状态 (1已创建 3输送线入库中 6堆垛机执行中 10已完成 20已放弃)
	--------------优先遍历正在执行的任务-----------------------------------------------------------------------------
	for k,v in pairs(self.data) do
			
		
		if self.ctn % 5000 == 0 and v.exstatus > 1 and v.exstatus < 10 then
			--logt(v)
		end
		
		if self.ctn % 5000 == 0 and v.exstatus > 10 then
			--logt(v)
		end
				
		
		local state = v.exstatus or 0
		local cmd = v.cmd or 0
		local dev = v.device or 0
		
		
		if self.ctn % 10 == 0 and state == 6 and dev == code and srm.WorkState == 3 and v.alarm == 0 then
			v.alarm = 1
			self:sendToRedis(v.taskid, v);
		end
		
		--任务放弃之后,需要清空堆垛机任务
		if state == 20 and dev == code and srm.SendType > 0 and srm.SendType < 100 and v.taskno == srm.TaskNo then
			srm.TaskType = 100
			srm.TempStation = v.taskno
			v.exstatus = 30
		end
		
		
		if cmd == 101 and state == 3 and dev == code then

			local idk,info = self:getStationInfo(v.tempStation);
			


			--//托盘已到达堆垛机入库缓存站台
			if (idk > 0 and info.readno  == info.code)
			then

				if (srm.WorkState ~= 10 and v.reasonCode ~= 27)
				then
					v.reason = "27|堆垛机不空闲";
					self:refreshTaskReason(27, v);

					---self:addLedState(dev, "堆垛机不空闲");

					return k , v
				end
				--log("==================================121--------",srm.WorkState,info.readyout)
				if (srm.WorkState == 10 and info.readystate == 2)
				then
					--FStations.SetStationComein(v.destMemo);
					local temp = tonumber(v.tempStation)
					
					local codenum = 0
					if info.code == 1001 then
						codenum = 1
					elseif info.code == 1005 then
						codenum = 2
					end
					log("-------------------------111",v.taskid)
					self:createCommand1(srm,v.taskid,v.taskno,1,v.srcRack,v.srcRow,v.srcCol,v.destRack,v.destRow,v.destCol,codenum,0,temp);

					THelper:saveSrmLog(v.device,v.taskid,5,v.cmd,"5.准备给堆垛机下发送入库任务")

					v.exstatus = 6;
					v.sendno = info.sendno;
					
					local dt = os.time();
					local st = os.date("%Y-%m-%dT%H:%M:%S", dt)					
					v.startTime = st
															
					self:refreshTaskInfo(6, v);

					---self:addLedState(dev, "堆垛机入库中");
				end
				
				
			end


			
			return 0,nil --入库任务中
		elseif cmd == 101 and state > 3 and state < 10 and dev == code then
			
			return 0,nil --入库任务中
		elseif cmd == 102 and state >= 3 and state < 10 and dev == code then
			
			return 0,nil --出库任务中
		elseif cmd == 103 and state >= 3 and state < 10 and dev == code then
			
			return 0,nil --移库任务中

		end

	end


	
	-------------遍历未执行的入库任务---------------------------------------------
	for k,v in pairs(self.data) do

		local state = v.exstatus or 0
		local cmd = v.cmd or 0
		--local dev = v.device or 0
		--local code = srm.key or 0
		--log("aaaa",v.cmd)
		local bb = 0
		--log("任务idc2",v.cmd,state,code)
		
		
		if v.cmd == 101 and state <= 2 and self:checkInbound(code, v) then				
			
			local move = string.format("%d至%s",v.srcStation,v.destMemo);
			
			if state == 1 then				
				v.exstatus = 2;
				return k , v
			end		
		
			local idc,info = self:getStationInfo(v.tempStation);
			
			log("idk11111111",idc,info.code,info.readno,info.readystate)
			if (idc <= 0 and v.reasonCode ~= 29)
			then
				v.reason = "29|站台"..v.tempStation.."信息有误";
				self:refreshTaskReason(29, v);

				ss = string.format("%d信息有误", v.tempStation);

				return k , v
			end	
			if (idc > 0 and info.readystate == 1  and v.reasonCode ~= 31)  then 
				v.reason = "31|站台"..v.tempStation.."输送线运行中";
				self:refreshTaskReason(31, v);
				return k , v
			end
			if (idc > 0 and (info.readystate == 3 or info.readystate == 0) and v.reasonCode ~= 32)  then 
				v.reason = "32|站台"..v.tempStation.."输送线报警";
				self:refreshTaskReason(32, v);
				return k , v
			end
			log("idk22222222",idc,info.code,info.readno,info.readystate)
			if idc > 0  and info.code == info.readno   and (info.readystate == 2 or info.readystate == 4)
			then
				log("条件满足")
				v.exstatus = 3
				info.requestY = 0
				return k,v
			end
			return k , v
		
		elseif v.cmd == 102 and state <= 2 and self:checkOutbound(code, v) then
			--出库任务
			local move = string.format("%s至%d",v.srcMemo,v.destStation)
			if state == 1 then
				
				---self:addLedMsg(code, v.taskid, move, v.barcode, "开始执行", 200);
				v.exstatus = 2;
				return k , v
			end
			
			
			local idc,info = self:getStationInfo(v.tempStation);
			--log("出库任务idc",idc,info.readyin)
			if (idc <= 0 and v.reasonCode ~= 29)
			then
			    ss = string.format("29|站台%d信息有误", v.tempStation);
				v.reason = ss
				
				self:refreshTaskReason(29, v);

				ss = string.format("%d信息有误", v.tempStation);
				return k , v
			end
			--log("srm.WorkState5",srm.WorkState,v.reasonCode)
			if (idc > 0 and info.readyin ~= 1 and v.reasonCode ~= 28)
			then
				ss = string.format("28|站台%d允入信号有误", v.tempStation);
				v.reason = ss
				self:refreshTaskReason(28, v);
				ss = string.format("%d允入有误", v.tempStation);
				return k , v
			
			elseif (srm.WorkState ~= 10 and v.reasonCode ~= 27)
			then
				v.reason = "27|堆垛机不空闲";
				self:refreshTaskReason(27, v);

				ss = "堆垛机不空闲";
				return k , v
			end

			if (srm.WorkState == 10)
			then

				local temp = tonumber(v.tempStation)
				------刷新堆垛机任务信息
				local destStationnum = 0
				local codenum = 0
				if v.destStation == 1004 then
					destStationnum = 3
				elseif info.code == 1008 then
					destStationnum = 4
				end
				log("-------------------------222",destStationnum)
				self:createCommand1(srm,v.taskid,v.taskno,2,v.srcRack,v.srcRow,v.srcCol,v.destRack,v.destRow,v.destCol,0,destStationnum,temp);
				--logt(srm)
				info.sendno = 0
				info.taskno = v.taskno
				info.device = v.device
				info.taskid = v.taskid
				v.exstatus = 6;
				local dt = os.time();
				local st = os.date("%Y-%m-%dT%H:%M:%S", dt)					
				v.startTime = st
				self:refreshTaskInfo(6, v);
				THelper:saveSrmLog(code,v.taskid,1,v.cmd,"1.准备给堆垛机下发送出库任务")

			end

			return k , v
		end

	end
	return 0,nil

end

-- 请求入库允许
function TTask:getStationInquest(srm)
	local ss = ""

	if #self.data <= 0 then
	
		return  0,nil
	end
	
	self.ctn = self.ctn + 1;
	if self.ctn > 9000 then self.ctn = 2 end
	--堆垛机编号
    local code = srm.key or 0
	
	if code == 0 then return 0,nil end

end

-----请求输送线入库任务
function TTask:requestInput(task)

	--log("给入库站台发送输送线入库任务")

	THelper:saveSrmLog(task.device,task.taskid,1,task.cmd,"1.给入库站台发送输送线入库任务")
	--给入库站台发送输送线入库任务
	local ss = "1,"..task.srcStation..","..task.tempStation
	
	TRedis:lpush("conInfo",ss)

	self:refreshTaskInfo(3,task)
    
	local move = string.format("%d至%s",task.srcStation,task.destMemo);
	---self:addLedMsg(task.device, task.taskid, move, task.barcode, "输送线入库中", 100);
	
	--self:addLedState(task.device, "输送线入库中");
end



function TTask:getStationInfo(scode)

	if (not xt or not xt.con1) then return 0,nil end

    local x = 0
	for i= 1 ,10 ,1 do
	--for kk,vv in pairs(xt.con1) do
		if (not xt.con1[i]) then return 0,nil end
		--log(kk,vv)
		for k,v in pairs(xt.con1[i]) do
			if (k == "code" and v == scode) then
				return i,xt.con1[i]
				--x = i
				--log(i,k,v)
			end

			--log(i,k,v)

		end

	end

	return 0,nil

end







----更新库位信息
function TTask:refreshGridInfo(state,code,task)
	
	
	local grid = TRedis:hmget1("gridlist",code)
	if grid then	
		
		if state == 2 then
			local dt = os.time();
			local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
			grid.inputTime = st
			grid.taskno = task.taskid
			grid.barcode = task.barcode
		end
	
		grid.state = state
		TRedis:createRedisInfo("gridlist",code,grid);
	end
	--local sql = string.format("update sys_task set reason = '', exstatus = %d,temp_station= '%d',backup1 = '%d',backup2 = '%d',update_time='%s' where sid='%s'",state,task.tempStation,task.sendno,task.device,st,task.sid);
	--log("refreshTaskInfo:",sql)
	--TSQLiteHelper:updateCommand(sql);

	
	

end


----更新任务信息
function TTask:refreshTaskInfo(state,task)
	local dt = os.time();
	local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
	
	task.exstatus = state;
	task.reason = "";
	
	local sql = string.format("update sys_task set reason = '', exstatus = %d,temp_station= '%d',backup1 = '%d',backup2 = '%d',update_time='%s' where sid='%s'",state,task.tempStation,task.sendno,task.device,st,task.sid);
	log("refreshTaskInfo:",sql)
	TSQLiteHelper:updateCommand(sql);

	
	self:sendToRedis(task.taskid, task);

end


function TTask:refreshTaskReason(rc,task)
	local dt = os.time();
	local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
	task.reasonCode = rc;
	
	local sql = string.format("update sys_task set reason = '%s',update_time='%s' where sid='%s'",task.reason,st,task.sid);
	log("refreshTaskReason:",sql)
	TSQLiteHelper:updateCommand(sql);

	
	self:sendToRedis(task.taskid, task);
end


function TTask:refreshWmsInfo(tid,ttype)
	local msg = "WMS强制操作";
	if (ttype == 5)
	then
		--//--给wms推送消息
		self:sendToWms(tid, ttype, "task force canceled");
		msg = "WMS已手动放弃";
		
	
	elseif (ttype == 6)
	then
		--//--给wms推送消息
		self:sendToWms(tid, ttype, "task force completed");
		msg = "WMS已强制完成";
	end
	
	local v,k = self:getTaskInfo(tid)
	
	if k <= 0 then return end
	
	v.exstatus = 20;
	v.reason = msg;
	
	local dt = os.time();
	local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
	
	local sql = string.format("update sys_task set reason = '%s',exstatus = 20,update_time='%s' where sid='%s'",msg,st,v.sid);
	log("refreshWmsInfo:",sql)
	TSQLiteHelper:updateCommand(sql);
	                          
	---self:addLedState(v.device, msg);	
	
	self:sendToRedis(v.taskid, v);

	--table.remove(self.data,k);
	
	
end


function TTask:addLedState1(code,msg)

	log(code,msg)

	local pkt={}
	pkt.cmd = 111
	pkt.workcode = code
	pkt.ledmsg3 = msg

	local tb_json = cjson8.encode(pkt)

	-- if (not self.client) then	
		-- self.client = TClientHelper:new("led","127.0.0.1",28887)
	-- end
	
    if self.client:checkConnect() then
		self.client:sendToServer1(string.char(2)..tb_json..string.char(3))
		
		--self.client:receiveFromServer()
		
	end

end


function TTask:addLedMsg1(code, tid, move, barcode, msg, ttype)

	log(code,tid,move,barcode,msg,ttype)

	local pkt={}
	pkt.cmd = ttype
	pkt.workcode = code
	pkt.ledmsg = move
	pkt.ledmsg1 = tid
	pkt.ledmsg2 = barcode
	pkt.ledmsg3 = msg

	local tb_json = cjson8.encode(pkt)
	--log(tb_json)
    
	-- if (not self.client) then	
		-- self.client = TClientHelper:new("led","127.0.0.1",28887)
	-- end
	
    if self.client and self.client:checkConnect() then
		self.client:sendToServer1(string.char(2)..tb_json..string.char(3))
		
		--self.client:receiveFromServer()
	end


end




--读取堆垛机任务执行情况信息---------
function TTask:readRunInfo(df)

	local msg = TRedis:rpop("runInfo")
	
	
	if msg and #msg > 0 then
		--log("run:"..msg)
		local rt =  self:analysisRun(msg)
		

	end
	
	
	
	
	--[[if df and df > 1 and self.client and self.client:checkConnect() then
		--接收LED服务心跳信息
		--耗时至少1秒钟
		self.client:receiveFromServer()
	end
	--]]

end


function TTask:analysisRun(msg)

	local req = split(msg,",")--//格式：指令类型,任务编号
	--log(req[1],req[2])
	local command = tonumber(req[1])
	local tno = tonumber(req[2])
	log("TEST_command:",command,tno)
    if (command == 10) then
	
		return self:completedTaskInfo(tno)

	elseif (command == 20) then
		return self:cancelTaskInfo(tno)
	elseif (command == 60) then
		return self:runningTaskInfo(tno)
	else
		return 100
	end

end



function TTask:completedTaskInfo(tno)

	local v,k = self:getTask(tno)
	if (k <= 0 or not v) then  return 0 end

	--local dt = DateTime.Now;
	--StationList slist = StationList.GetInstance();
	--log(1,v.taskid,v.taskType,v.exstatus)
	
	local bb = 0
	
	log("测试任务上传wms1",v.taskType,v.exstatus)
	if (v.taskType == 100 and v.exstatus >= 6 and v.exstatus < 10)
	then

		-- local ix = slist.GetIndexByDBNo(WMS_TASK[sn].destMemo);
		-- if (ix >= 0)
		-- then
			-- slist.SetStationFull(ix, WMS_TASK[sn].taskid, WMS_TASK[sn].barcode);
		-- end
		--log(3,v.taskid)
		
		bb = 1

		-- self:sendToWms(v.taskid, 3, "task completed");

		-- v.exstatus = 10;
		-- v.reason = "";
		
		
		-- local dt = os.time();
		-- local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
		-- local sql = string.format("update sys_task set reason = '', exstatus = 10,restatus= 2,update_time='%s' where sid='%s'",st,v.sid);
		-- TSQLiteHelper.UpdateCommand(sql);
		-- --log(10,v.taskid,v.exstatus)
		-- self:addLedState(v.device, "已自动完成");
		
		
		-- self:sendToRedis(v.taskid, v);

		-- table.remove(self.data,k);
		
		-- return 0
		
		--置满目标库位
		self:refreshGridInfo(2,v.destMemo,v)


	elseif (v.taskType == 200 and v.exstatus >= 6 and v.exstatus < 10)
	then

		--slist.SetStationEmpty(v.srcMemo);
		--log(3,v.taskid)
		
		bb = 1
		--置空起点库位
		self:refreshGridInfo(1,v.srcMemo,v)
		
	end
	
	
	if bb == 1 then
		
		log("测试任务上传wms2",bb)
		self:sendToWms(v.taskid, 3, "task completed");

		v.exstatus = 10;
		v.reason = "";
		local dt = os.time();
		local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
		
		local sql3 = string.format("update sys_task set reason = '',exstatus = 10,restatus = 2,update_time='%s' where sid='%s'",st,v.sid);
		log("completedTaskInfo:",sql)
		TSQLiteHelper:updateCommand(sql3);
		--log(10,v.taskid)
		---self:addLedState(v.device, "已自动完成");

		
		self:sendToRedis(v.taskid, v);

		--table.remove(self.data,k);
		
		return 0
	
	
	end
	
	return 1
end



function TTask:cancelTaskInfo(tno)
	local v,k = self:getTask(tno)
	if (k <= 0 or not v) then  return 0 end

	v.exstatus = 20;
	v.reason = "已手动放弃";
	
	local dt = os.time();
	local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
	local sql = string.format("update sys_task set reason = '已手动放弃',exstatus = 20,update_time='%s' where sid='%s'",st,v.sid);
	log("cancelTaskInfo:",sql)
	TSQLiteHelper:updateCommand(sql);

	self:sendToWms(v.taskid, 5, "task force canceled");

	---self:addLedState(v.device, "已手动放弃");

	
	self:sendToRedis(v.taskid, v);
     
	--table.remove(self.data,k);
	
	return 0

end

function TTask:runningTaskInfo(tno)
	local v,k = self:getTask(tno)
	if (k <= 0 or not v) then  return 0 end

	v.exstatus = 6;
	v.reason = "任务执行中";
	
	local dt = os.time();
	local st = os.date("%Y-%m-%dT%H:%M:%S", dt)
	local sql = string.format("update sys_task set reason = '任务执行中',exstatus = 6,update_time='%s' where sid='%s'",st,v.sid);
	log("task running:",sql)
	TSQLiteHelper:updateCommand(sql);

	self:sendToWms(v.taskid,1,"task running");

	self:sendToRedis(v.taskid,v);
	
	return 0

end

function TTask:sendToWms(tid,state,msg)
		--local cjson = require "cjson"
		--local pk = {cmd = 201,task_id = tid,task_status = state,task_info = msg}
		--local ss = loadstring("return " ..pk)()
		--转码至json
		--local ss = cjson8.encode(pk)

		--local jsonString = '{"name":"John","age":30,"city":"New York"}'
        --local jsonData = load("return " .. pk)()

		--log(ss)

		--ss = '{"cmd":101,"seq":83,"task_id":19758,"src_station":102,"dest_station":0,"src_rack":0,"src_col":0,"src_row":0,"dest_rack":2,"dest_col":3,"dest_row":3,"weight":0.0,"barcode":"T1314"}'
		--解码为LUA对象
		--pk = cjson8.decode(ss)

        --logt(pk)

		--if (xt.wmsInfo and xt.wmsIndex and xt.wmsIndex >= 1) then

		--回复WMS任务执行情况
		local pk = {cmd = 201,task_id = tid,task_status = state,task_info = msg}
		local ss = cjson8.encode(pk)

		log(ss)
		
		-- 
		
		TRedis:lpush("wmsInfo",ss)

		-- xshare.lock(xt);
		-- xt.wmsInfo[xt.wmsIndex] = ss
		-- xt.wmsIndex = xt.wmsIndex + 1
		-- xshare.unlock(xt);

	--end

end
