--输送线元类:Metaclass
TConEquipmentTest = {Ident = 20,}

local xt = xshare.new('muthread share table')

function TConEquipmentTest:new(key,ip,port,start,count)
	local obj = {info= {},run ={},con = {}}
	--setmetatable(obj, self)
	setmetatable(obj,{__index = self})
	obj.__index = self
	
	self[key] = obj

	obj["info"].ip = ip
	obj["info"].port = port or 102
	--obj["info"].name = name
	--obj["info"].key = key
	local client = TClientHelper:new(key,ip,port)
    obj.client = client

	for i= 1 ,count , 1 do
		obj.con[i] = {}
		obj.con[i].code = start + i
		obj.con[i].offset = (i - 1) * 10 
		
		--1.输送线站台信息 -> 共享站台信息 
		obj.con[i].readno = 1  -- 任务id 
		obj.con[i].src = 0    
		obj.con[i].dest = 0
		obj.con[i].weight = 0
		obj.con[i].shape = 0
		obj.con[i].readyin = 1
		obj.con[i].readyOK = 1
		obj.con[i].readystate = 0
		obj.con[i].barcode = ""
		--2.共享站台信息 -> 输送线站台信息
		obj.con[i].sendno = 0
		obj.con[i].taskno = 0
		obj.con[i].device = 0
		obj.con[i].taskid = 0
		obj.con[i].readRFID = ""
		obj.con[i].constate = 0
		obj.con[i].requestY = 0
	end

	obj.index = 1
	obj.rid = 1
	
	obj["run"].sendno = 1

    return obj

end

--注意:一次读取的数据块要小于220byte
function TConEquipmentTest:reader(scon,xcon)
	--读取1001至1004所有站台信息
	
		local address = 0
		local input = TModbusHelper:createReader4(71,49)	
		--2.TCP通信获取寄存器信息
		local count = TModbusHelper.ReceiveCount
		local output = self.client:sendToServer22(input,count)
		--log("outputcon",#output)
		if output and #output == 107 then
			if self:readPlcValue(scon,xcon,output,address)	then
				self:getStationInquest()
			else
				self.client:closeSocket()
			end
			
		end
	
end

function TConEquipmentTest:createSendBuffer()
	-- 判断是否连接
	if self.client:checkConnect()  then
		local addr  = TRedis:rpop("con_alarm")
		
		if addr and #addr > 0 then 
			local input = TModbusHelper:createByteWriter4(addr)
			local count = 12		
			local output = self.client:sendToServer22(input,count)
			
			if (output and #output == count)then
				if TModbusHelper:CheckWriteValue(output,addr) then
					log("写输送线报警成功")
				else
					self.client:closeSocket()
				end
			end
		end	
		
	end
end

function TConEquipmentTest:createSendBufferAGV(addr)
	-- 判断是否连接
	if self.client:checkConnect()  then
		
		--log("aaaaaaaa-----------------------",addr)
		if addr and addr > 0 then 
			local input = TModbusHelper:createByteWriter5(addr)
			local count = 12		
			local output = self.client:sendToServer22(input,count)
			
			if (output and #output == count)then
				if TModbusHelper:CheckWriteValue(output,addr) then
					--log("写AGV目的地成功")
				else
					self.client:closeSocket()
				end
			end
		end	
		
	end
end

-- 读入库
function TConEquipmentTest:getStationInquest()
	local station,x_1_barcode,seq,x_2_barcode,tray_size,tray_weight
	if (not xt or not xt.con1) then return 0,nil end

    local x = 0
	
	for i= 1 ,10 ,1 do
		if (not xt.con1[i]) then 
			return 0,nil 
		end
		for k,v in pairs(xt.con1[i]) do
		    if k == "code" and (v == 1001 or v == 1005) then
				local con_in = xt.con1[i]
				local con_in2 = xt.con1[i+1]
				if  con_in.readRFID and #con_in.readRFID > 6 and con_in.requestY == 0 and con_in.readno == con_in.code  then
					-- 向WMS发送入库申请		
					local pk = {cmd = 203,station = con_in2.code ,x_1_barcode = con_in.readRFID,seq = 1,x_2_barcode = "",tray_size = 0,tray_weight= 0}
					local ss = cjson8.encode(pk)
					log(ss)
					TRedis:lpush("wmsInfo",ss)	
					-- con_in.requestY = 1 -- [Masked]
				end	
                if con_in.requestY == 1  and  con_in.readno ~= con_in.code  then
					con_in.requestY = 0
				end
			end
			
			if  k == "code" and v == 1007 then
				local con_out = xt.con1[i]
				if  con_out.readRFID and #con_out.readRFID > 6  then
					
					local length = TRedis:llen("agv_dests")
					if length and length > 2 then
						TRedis:rpop("agv_dests")
					elseif length and length > 0 and length < 3 then
						for j = 0, length - 1 ,1 do
							local msg = TRedis:safe_lindex("agv_dests", j)
							if msg then
								local agv_d = cjson9.decode(msg)
								local task_id =  math.ceil(agv_d.task_id)
								--log("0000000000001",task_id,con_out.readno)
								if task_id and task_id == con_out.readno and con_out.readystate == 2 then
									local addr = math.ceil(agv_d.agv_dest)
									log("11111111111111",addr)
									self:createSendBufferAGV(addr)
									TRedis:safeRemoveListElement("agv_dests", j)
								end
							end
						end
					end	
				end
				if con_out.readRFID and #con_out.readRFID == 0  and  con_out.readyOK == 1   then
					--log("物料出完成,清AGV目的地")
					
					--self:createSendBufferAGV(0)
				end
			end	
		end		
	end
end




--构造PLC写byte指令
function TConEquipmentTest:writer(addr,count,input)
	local address = 0
	local input = TModbusHelper:createReader5(addr,count,input)
	local output = self.client:sendToServer22(input,12)
	if output and #output == 12 then
		if TModbusHelper:CheckWriteValue(output,count) then
			--THelper:saveSrmLog(self.info.key,self.task.TaskId,3,self.task.TaskType,"3.堆垛机指令已下发完成")
			return true	
		else
			self.client:closeSocket()
		end
	end
	
	return false
	
end


--读取刷新输送线站台和共享站台信息
function TConEquipmentTest:readPlcValue(con,xcon,ReadData,address)
	local faddr =  address
	
	local n =  faddr + 1;
	--log(n,"站台数据:",#ReadData,faddr)
	if not ReadData or not con or #ReadData < 107 then
		return
	end	
	
	for i =1, 8, 1 do
	
	con[i].constate = TByteHelper:toInt16(ReadData,10)
	xcon[i].constate = con[i].constate
	end
	-- 1001--------------------------------------------------- 
	con[1].readRFID = TByteHelper:readRegistersToArray(ReadData,29,12)
	xcon[1].readRFID = con[1].readRFID
	con[1].readno = TByteHelper:toInt16(ReadData,18)
	xcon[1].readno = con[1].readno	
	--任务状态信号
	con[1].readystate = TByteHelper:toInt16(ReadData,16)
	xcon[1].readystate = con[1].readystate

	-- 1002 -----------------------------------------------------------
	con[2].readRFID = TByteHelper:readRegistersToArray(ReadData,29,12)
	xcon[2].readRFID = con[2].readRFID
	con[2].readno = TByteHelper:toInt16(ReadData,20)
	xcon[2].readno = con[2].readno 	
	--任务状态信号
	con[2].readystate = TByteHelper:toInt16(ReadData,16)
	xcon[2].readystate = con[2].readystate
	
	
	--log("1002站台值",con[2].readno,con[2].readyout,con[2].readRFID,con[2].readystate,con[2].device,con[2].taskno,con[2].taskid,con[2].constate)
   --  1003---------------------------------------------------
	con[3].readRFID = TByteHelper:readRegistersToArray(ReadData,43,12)
	xcon[3].readRFID = con[3].readRFID
	con[3].readno = TByteHelper:toInt16(ReadData,26)
	xcon[3].readno = con[3].readno	
	--任务状态信号
	con[3].readystate = TByteHelper:toInt16(ReadData,24)
	xcon[3].readystate = con[3].readystate	
	con[3].readyOK = TByteHelper:toInt16(ReadData,104)
	xcon[3].readyOK = con[3].readyOK
	-- 1004 -----------------------------------------
	--[[
	00 62 00 00 00 3F 02 03 3C
	00 01 00 00 00 02 00 01 00 02
	03 E9 03 EA 00 01 00 01 00 01
	03 EB 00 00 00 01 41 31 42 32
	43 33 44 34 45 35 46 36 00 00
	00 00 00 00 00 00 00 00 00 00
	00 00 00 00 00 00 00 00 00 00
	--]]
	con[4].readRFID = TByteHelper:readRegistersToArray(ReadData,43,12)
	xcon[4].readRFID = con[4].readRFID
	con[4].readno = 1004
	xcon[4].readno = con[4].readno	
	--任务状态信号
	con[4].readystate = TByteHelper:toInt16(ReadData,24)
	xcon[4].readystate = con[4].readystate
	con[4].readyin = TByteHelper:toInt16(ReadData,100)
	xcon[4].readyin = con[4].readyin		

	con[5].readRFID = TByteHelper:readRegistersToArray(ReadData,71,12)
	xcon[5].readRFID = con[5].readRFID
	con[5].readno = TByteHelper:toInt16(ReadData,60)
	xcon[5].readno = con[5].readno	
	--任务状态信号
	con[5].readystate = TByteHelper:toInt16(ReadData,58)
	xcon[5].readystate = con[5].readystate
	
	con[6].readRFID = TByteHelper:readRegistersToArray(ReadData,71,12)
	xcon[6].readRFID = con[6].readRFID
	con[6].readno = TByteHelper:toInt16(ReadData,62)
	xcon[6].readno = con[6].readno	
	--任务状态信号
	con[6].readystate = TByteHelper:toInt16(ReadData,58)
	xcon[6].readystate = con[6].readystate
	
	con[7].readRFID = TByteHelper:readRegistersToArray(ReadData,85,12)
	xcon[7].readRFID = con[7].readRFID
	con[7].readno = TByteHelper:toInt16(ReadData,68)
	xcon[7].readno = con[7].readno	
	--任务状态信号
	con[7].readystate = TByteHelper:toInt16(ReadData,66)
	xcon[7].readystate = con[7].readystate
	con[7].readyOK = TByteHelper:toInt16(ReadData,106)
	xcon[7].readyOK = con[7].readyOK
	
	con[8].readRFID = TByteHelper:readRegistersToArray(ReadData,85,12)
	xcon[8].readRFID = con[7].readRFID
	con[8].readno = 1008
	xcon[8].readno = con[8].readno	
	--任务状态信号
	con[8].readystate = TByteHelper:toInt16(ReadData,66)
	xcon[8].readystate = con[8].readystate
	
	con[8].readyin = TByteHelper:toInt16(ReadData,102)
	xcon[8].readyin = con[8].readyin

	--2.共享站台信息 -> 输送线站台信息	
	for i =1, 8, 1 do
	
		con[i].device = xcon[i].device
		con[i].taskno = xcon[i].taskno
		con[i].taskid = xcon[i].taskid
		
		--3.输送线站台信息  -> 共享站台信息
		xcon[i].sendno = con[i].sendno
	end
	
	return true
	
end	


function TConEquipmentTest:writeTask2(s1,s2,s3)
	--写AGV目的地
	
	self:createSendBufferAGV(1)	
	log("写AGV目的地成功:",s2)
	return 0
end

function TConEquipmentTest:analysisCommand(msg)
	local req = split(msg,",")--//格式：指令类型,起点站台,终点编号
	local command = tonumber(req[1])
    if (command == 2 and 1 == 2) then
		return self:writeTask2(req[2],req[3],req[4])
	end
	return 0
end

------读取并解析输送线任务信息-------------
function TConEquipmentTest:readConvInfo()
	local msg = TRedis:rpop("conInfo")
	if msg and #msg > 2 then
	    log("输送线任务:",msg)
		local rt =  self:analysisCommand(msg)
	end
end


function TConEquipmentTest:worker(xcon)
	
	local dt1 = os.time()
	local dt2 = os.time()
	local df = 0;
	
	local ctn = 1
    
	log("输送线交互线程已启动")
	THelper:saveWmsLog("输送线交互线程已启动",self.info.ip..":"..self.info.port)
	while true  do
	
		THelper:sleep(0.1)
		
		if ctn > 90000 then ctn = 2 else ctn =  ctn + 1 end
		
		dt2 = os.time()		
		df = os.difftime(dt2, dt1)
		
		if (df > 1) then
			dt1 = dt2
			--log("输送线线程",ctn,df)
			ctn = 1
		end
		--读取输送线PLC信息
		if ctn % 10 == 0 and self.client:checkConnect() then
			self:reader(self.con,xcon)
			self:createSendBuffer()
		end
		
		--读取并解析输送线任务信息
		if ctn % 3 == 0  then self:readConvInfo() 
		end
		
	end
end
