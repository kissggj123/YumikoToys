//
//  NIOModels.swift
//  YumikoToys
//
//  蔚来 NIO 数据模型（从 NIO-Dash TypeScript 重写）
//

import Foundation

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
}

// MARK: - 车辆 RVS 状态响应

struct NIOVehicleResponse: Codable {
    var requestId: String?
    var resultCode: String?
    var serverTime: Double?
    var data: NIOVehicleData?

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case resultCode = "result_code"
        case serverTime = "server_time"
        case data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try? c.decodeIfPresent(String.self, forKey: .requestId)
        if let s = try? c.decodeIfPresent(String.self, forKey: .resultCode) {
            resultCode = s
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .resultCode) {
            resultCode = String(i)
        }
        if let d = try? c.decodeIfPresent(Double.self, forKey: .serverTime) {
            serverTime = d
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .serverTime) {
            serverTime = Double(i)
        }
        data = try? c.decodeIfPresent(NIOVehicleData.self, forKey: .data)
    }

    init(requestId: String? = nil, resultCode: String? = nil, serverTime: Double? = nil, data: NIOVehicleData? = nil) {
        self.requestId = requestId
        self.resultCode = resultCode
        self.serverTime = serverTime
        self.data = data
    }
}

struct NIOVehicleData: Codable {
    var checkedIn: NIOCheckedIn?
    var alarm: [NIOJSONValue]?
    var status: NIOVehicleStatus?

    enum CodingKeys: String, CodingKey {
        case checkedIn = "checked_in"
        case alarm, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        checkedIn = try? c.decodeIfPresent(NIOCheckedIn.self, forKey: .checkedIn)
        alarm = try? c.decodeIfPresent([NIOJSONValue].self, forKey: .alarm)
        status = try? c.decodeIfPresent(NIOVehicleStatus.self, forKey: .status)
    }

    init(checkedIn: NIOCheckedIn? = nil, alarm: [NIOJSONValue]? = nil, status: NIOVehicleStatus? = nil) {
        self.checkedIn = checkedIn
        self.alarm = alarm
        self.status = status
    }
}

struct NIOCheckedIn: Codable {
    var checked: Bool?
    var days: Int?

    enum CodingKeys: String, CodingKey {
        case checked, days
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let b = try? c.decodeIfPresent(Bool.self, forKey: .checked) {
            checked = b
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .checked) {
            checked = (i != 0)
        }
        if let i = try? c.decodeIfPresent(Int.self, forKey: .days) {
            days = i
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .days) {
            days = Int(d)
        }
    }

    init(checked: Bool? = nil, days: Int? = nil) {
        self.checked = checked
        self.days = days
    }
}

struct NIOAlarm: Codable {}

struct NIOVehicleStatus: Codable {
    var hvacStatus: NIOHvacStatus?
    var heatingStatus: [String: NIOJSONValue]?
    var positionStatus: NIOPositionStatus?
    var connectionStatus: NIOConnectionStatus?
    var offcarModeStatus: [String: NIOJSONValue]?
    var maintainStatus: NIOMaintainStatus?
    var windowStatus: [String: NIOJSONValue]?
    var exteriorStatus: NIOExteriorStatus?
    var fotaStatus: NIOFotaStatus?
    var socStatus: NIOSocStatus?
    var vehicleId: String?
    var doorStatus: [String: NIOJSONValue]?
    var tyreStatus: [String: NIOJSONValue]?
    var lightStatus: [String: NIOJSONValue]?
    var keyStatus: [String: NIOJSONValue]?
    var specialStatus: [String: NIOJSONValue]?
    var tripShareStatus: [String: NIOJSONValue]?
    var nearbyCarCtrl: [String: NIOJSONValue]?
    var powerSwapOrder: [String: NIOJSONValue]?
    var lvBattStatus: [String: NIOJSONValue]?
    var deviceStatus: [String: NIOJSONValue]?
    var chargeStatusOrder: [String: NIOJSONValue]?
    var remoteOperateStatus: [String: NIOJSONValue]?
    var offcarPowerSwapStatus: [String: NIOJSONValue]?
    var boxStatus: [String: NIOJSONValue]?
    var frdgStatus: [String: NIOJSONValue]?

    enum CodingKeys: String, CodingKey {
        case hvacStatus = "hvac_status"
        case heatingStatus = "heating_status"
        case positionStatus = "position_status"
        case connectionStatus = "connection_status"
        case offcarModeStatus = "offcar_mode_status"
        case maintainStatus = "maintain_status"
        case windowStatus = "window_status"
        case exteriorStatus = "exterior_status"
        case fotaStatus = "fota_status"
        case socStatus = "soc_status"
        case vehicleId = "vehicle_id"
        case doorStatus = "door_status"
        case tyreStatus = "tyre_status"
        case lightStatus = "light_status"
        case keyStatus = "key_status"
        case specialStatus = "special_status"
        case tripShareStatus = "trip_share_status"
        case nearbyCarCtrl = "nearby_car_ctrl"
        case powerSwapOrder = "power_swap_order"
        case lvBattStatus = "lv_batt_status"
        case deviceStatus = "device_status"
        case chargeStatusOrder = "charge_status_order"
        case remoteOperateStatus = "remote_operate_status"
        case offcarPowerSwapStatus = "offcar_power_swap_status"
        case boxStatus = "box_status"
        case frdgStatus = "frdg_status"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hvacStatus = try? c.decodeIfPresent(NIOHvacStatus.self, forKey: .hvacStatus)
        heatingStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .heatingStatus)
        positionStatus = try? c.decodeIfPresent(NIOPositionStatus.self, forKey: .positionStatus)
        connectionStatus = try? c.decodeIfPresent(NIOConnectionStatus.self, forKey: .connectionStatus)
        offcarModeStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .offcarModeStatus)
        maintainStatus = try? c.decodeIfPresent(NIOMaintainStatus.self, forKey: .maintainStatus)
        windowStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .windowStatus)
        exteriorStatus = try? c.decodeIfPresent(NIOExteriorStatus.self, forKey: .exteriorStatus)
        fotaStatus = try? c.decodeIfPresent(NIOFotaStatus.self, forKey: .fotaStatus)
        socStatus = try? c.decodeIfPresent(NIOSocStatus.self, forKey: .socStatus)
        vehicleId = try? c.decodeIfPresent(String.self, forKey: .vehicleId)
        doorStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .doorStatus)
        if let directTyre = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .tyreStatus) {
            tyreStatus = directTyre
        } else {
            let dc = try? decoder.container(keyedBy: DynamicCodingKey.self)
            for k in ["tire_status", "tyre", "tire", "tyres", "tires", "tyre_pressure", "tire_pressure", "tpms_status", "tyre_press_status"] {
                if let key = DynamicCodingKey(stringValue: k),
                   let val = try? dc?.decodeIfPresent([String: NIOJSONValue].self, forKey: key) {
                    tyreStatus = val
                    break
                }
            }
        }
        lightStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .lightStatus)
        keyStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .keyStatus)
        specialStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .specialStatus)
        tripShareStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .tripShareStatus)
        nearbyCarCtrl = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .nearbyCarCtrl)
        powerSwapOrder = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .powerSwapOrder)
        lvBattStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .lvBattStatus)
        deviceStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .deviceStatus)
        chargeStatusOrder = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .chargeStatusOrder)
        remoteOperateStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .remoteOperateStatus)
        offcarPowerSwapStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .offcarPowerSwapStatus)
        boxStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .boxStatus)
        frdgStatus = try? c.decodeIfPresent([String: NIOJSONValue].self, forKey: .frdgStatus)
    }

    init(
        hvacStatus: NIOHvacStatus? = nil,
        heatingStatus: [String: NIOJSONValue]? = nil,
        positionStatus: NIOPositionStatus? = nil,
        connectionStatus: NIOConnectionStatus? = nil,
        offcarModeStatus: [String: NIOJSONValue]? = nil,
        maintainStatus: NIOMaintainStatus? = nil,
        windowStatus: [String: NIOJSONValue]? = nil,
        exteriorStatus: NIOExteriorStatus? = nil,
        fotaStatus: NIOFotaStatus? = nil,
        socStatus: NIOSocStatus? = nil,
        vehicleId: String? = nil,
        doorStatus: [String: NIOJSONValue]? = nil,
        tyreStatus: [String: NIOJSONValue]? = nil,
        lightStatus: [String: NIOJSONValue]? = nil,
        keyStatus: [String: NIOJSONValue]? = nil,
        specialStatus: [String: NIOJSONValue]? = nil,
        tripShareStatus: [String: NIOJSONValue]? = nil,
        nearbyCarCtrl: [String: NIOJSONValue]? = nil,
        powerSwapOrder: [String: NIOJSONValue]? = nil,
        lvBattStatus: [String: NIOJSONValue]? = nil,
        deviceStatus: [String: NIOJSONValue]? = nil,
        chargeStatusOrder: [String: NIOJSONValue]? = nil,
        remoteOperateStatus: [String: NIOJSONValue]? = nil,
        offcarPowerSwapStatus: [String: NIOJSONValue]? = nil,
        boxStatus: [String: NIOJSONValue]? = nil,
        frdgStatus: [String: NIOJSONValue]? = nil
    ) {
        self.hvacStatus = hvacStatus
        self.heatingStatus = heatingStatus
        self.positionStatus = positionStatus
        self.connectionStatus = connectionStatus
        self.offcarModeStatus = offcarModeStatus
        self.maintainStatus = maintainStatus
        self.windowStatus = windowStatus
        self.exteriorStatus = exteriorStatus
        self.fotaStatus = fotaStatus
        self.socStatus = socStatus
        self.vehicleId = vehicleId
        self.doorStatus = doorStatus
        self.tyreStatus = tyreStatus
        self.lightStatus = lightStatus
        self.keyStatus = keyStatus
        self.specialStatus = specialStatus
        self.tripShareStatus = tripShareStatus
        self.nearbyCarCtrl = nearbyCarCtrl
        self.powerSwapOrder = powerSwapOrder
        self.lvBattStatus = lvBattStatus
        self.deviceStatus = deviceStatus
        self.chargeStatusOrder = chargeStatusOrder
        self.remoteOperateStatus = remoteOperateStatus
        self.offcarPowerSwapStatus = offcarPowerSwapStatus
        self.boxStatus = boxStatus
        self.frdgStatus = frdgStatus
    }
}

struct NIOHvacStatus: Codable {
    var temperature: Double?
    var outsideTemperature: Double?
    var airConditionerOn: Bool?
    var sampleTime: Int?
    var cbnHiTDrySts: Int?
    var ccuMaxDefrstSts: Int?
    var ccuAcmaxLampReq: Int?
    var ccuHeatgMaxLampReq: Int?
    var cbnOvrHtActSts: Int?
    var remSensClimateSetSts: Int?

    enum CodingKeys: String, CodingKey {
        case temperature
        case ccuCbnT = "ccu_cbn_t"
        case cbnT = "cbn_t"
        case insideTemperature = "inside_temperature"
        case cabinTemperature = "cabin_temperature"
        case outsideTemperature = "outside_temperature"
        case ccuAmbT = "ccu_amb_t"
        case ambT = "amb_t"
        case ambientTemperature = "ambient_temperature"
        case airConditionerOn = "air_conditioner_on"
        case acOn = "ac_on"
        case ccuAcOn = "ccu_ac_on"
        case sampleTime = "sample_time"
        case cbnHiTDrySts = "cbn_hi_t_dry_sts"
        case ccuMaxDefrstSts = "ccu_max_defrst_sts"
        case ccuAcmaxLampReq = "ccu_acmax_lamp_req"
        case ccuHeatgMaxLampReq = "ccu_heatg_max_lamp_req"
        case cbnOvrHtActSts = "cbn_ovr_ht_act_sts"
        case remSensClimateSetSts = "rem_sens_climate_set_sts"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let d = try? c.decodeIfPresent(Double.self, forKey: .temperature) {
            temperature = d
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .ccuCbnT) {
            temperature = d
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .cbnT) {
            temperature = d
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .insideTemperature) {
            temperature = d
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .cabinTemperature) {
            temperature = d
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .temperature) {
            temperature = Double(i)
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .ccuCbnT) {
            temperature = Double(i)
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .temperature) {
            temperature = Double(s)
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .ccuCbnT) {
            temperature = Double(s)
        }

        if let d = try? c.decodeIfPresent(Double.self, forKey: .outsideTemperature) {
            outsideTemperature = d
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .ccuAmbT) {
            outsideTemperature = d
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .ambT) {
            outsideTemperature = d
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .ambientTemperature) {
            outsideTemperature = d
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .outsideTemperature) {
            outsideTemperature = Double(i)
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .ccuAmbT) {
            outsideTemperature = Double(i)
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .outsideTemperature) {
            outsideTemperature = Double(s)
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .ccuAmbT) {
            outsideTemperature = Double(s)
        }

        if let b = try? c.decodeIfPresent(Bool.self, forKey: .airConditionerOn) {
            airConditionerOn = b
        } else if let b = try? c.decodeIfPresent(Bool.self, forKey: .acOn) {
            airConditionerOn = b
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .airConditionerOn) {
            airConditionerOn = (i != 0)
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .acOn) {
            airConditionerOn = (i != 0)
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .ccuAcOn) {
            airConditionerOn = (i != 0)
        }

        if let i = try? c.decodeIfPresent(Int.self, forKey: .sampleTime) {
            sampleTime = i
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .sampleTime) {
            sampleTime = Int(d)
        }
        cbnHiTDrySts = (try? c.decodeIfPresent(Int.self, forKey: .cbnHiTDrySts)) ?? (try? c.decodeIfPresent(String.self, forKey: .cbnHiTDrySts)).flatMap { Int($0) }
        ccuMaxDefrstSts = (try? c.decodeIfPresent(Int.self, forKey: .ccuMaxDefrstSts)) ?? (try? c.decodeIfPresent(String.self, forKey: .ccuMaxDefrstSts)).flatMap { Int($0) }
        ccuAcmaxLampReq = (try? c.decodeIfPresent(Int.self, forKey: .ccuAcmaxLampReq)) ?? (try? c.decodeIfPresent(String.self, forKey: .ccuAcmaxLampReq)).flatMap { Int($0) }
        ccuHeatgMaxLampReq = (try? c.decodeIfPresent(Int.self, forKey: .ccuHeatgMaxLampReq)) ?? (try? c.decodeIfPresent(String.self, forKey: .ccuHeatgMaxLampReq)).flatMap { Int($0) }
        cbnOvrHtActSts = (try? c.decodeIfPresent(Int.self, forKey: .cbnOvrHtActSts)) ?? (try? c.decodeIfPresent(String.self, forKey: .cbnOvrHtActSts)).flatMap { Int($0) }
        remSensClimateSetSts = (try? c.decodeIfPresent(Int.self, forKey: .remSensClimateSetSts)) ?? (try? c.decodeIfPresent(String.self, forKey: .remSensClimateSetSts)).flatMap { Int($0) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(outsideTemperature, forKey: .outsideTemperature)
        try container.encodeIfPresent(airConditionerOn, forKey: .airConditionerOn)
        try container.encodeIfPresent(sampleTime, forKey: .sampleTime)
        try container.encodeIfPresent(cbnHiTDrySts, forKey: .cbnHiTDrySts)
        try container.encodeIfPresent(ccuMaxDefrstSts, forKey: .ccuMaxDefrstSts)
        try container.encodeIfPresent(ccuAcmaxLampReq, forKey: .ccuAcmaxLampReq)
        try container.encodeIfPresent(ccuHeatgMaxLampReq, forKey: .ccuHeatgMaxLampReq)
        try container.encodeIfPresent(cbnOvrHtActSts, forKey: .cbnOvrHtActSts)
        try container.encodeIfPresent(remSensClimateSetSts, forKey: .remSensClimateSetSts)
    }

    init(temperature: Double? = nil, outsideTemperature: Double? = nil, airConditionerOn: Bool? = nil, sampleTime: Int? = nil, cbnHiTDrySts: Int? = nil, ccuMaxDefrstSts: Int? = nil, ccuAcmaxLampReq: Int? = nil, ccuHeatgMaxLampReq: Int? = nil, cbnOvrHtActSts: Int? = nil, remSensClimateSetSts: Int? = nil) {
        self.temperature = temperature
        self.outsideTemperature = outsideTemperature
        self.airConditionerOn = airConditionerOn
        self.sampleTime = sampleTime
        self.cbnHiTDrySts = cbnHiTDrySts
        self.ccuMaxDefrstSts = ccuMaxDefrstSts
        self.ccuAcmaxLampReq = ccuAcmaxLampReq
        self.ccuHeatgMaxLampReq = ccuHeatgMaxLampReq
        self.cbnOvrHtActSts = cbnOvrHtActSts
        self.remSensClimateSetSts = remSensClimateSetSts
    }
}

struct NIOPositionStatus: Codable {
    var longitude: Double?
    var latitude: Double?
    var sampleTime: Int?

    enum CodingKeys: String, CodingKey {
        case longitude, latitude
        case sampleTime = "sample_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let d = try? c.decodeIfPresent(Double.self, forKey: .longitude) {
            longitude = d
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .longitude) {
            longitude = Double(s)
        }
        if let d = try? c.decodeIfPresent(Double.self, forKey: .latitude) {
            latitude = d
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .latitude) {
            latitude = Double(s)
        }
        if let i = try? c.decodeIfPresent(Int.self, forKey: .sampleTime) {
            sampleTime = i
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .sampleTime) {
            sampleTime = Int(d)
        }
    }

    init(longitude: Double? = nil, latitude: Double? = nil, sampleTime: Int? = nil) {
        self.longitude = longitude
        self.latitude = latitude
        self.sampleTime = sampleTime
    }
}

struct NIOConnectionStatus: Codable {
    var connected: Bool?
    var cdcConnected: Bool?
    var adcConnected: Bool?
    var updateTime: Int?

    enum CodingKeys: String, CodingKey {
        case connected
        case cdcConnected = "cdc_connected"
        case adcConnected = "adc_connected"
        case updateTime = "update_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func getBool(_ key: CodingKeys) -> Bool? {
            if let b = try? c.decodeIfPresent(Bool.self, forKey: key) { return b }
            if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return (i != 0) }
            if let s = try? c.decodeIfPresent(String.self, forKey: key) {
                return (s == "1" || s.lowercased() == "true")
            }
            return nil
        }
        connected = getBool(.connected)
        cdcConnected = getBool(.cdcConnected)
        adcConnected = getBool(.adcConnected)
        if let i = try? c.decodeIfPresent(Int.self, forKey: .updateTime) {
            updateTime = i
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .updateTime) {
            updateTime = Int(d)
        }
    }

    init(connected: Bool? = nil, cdcConnected: Bool? = nil, adcConnected: Bool? = nil, updateTime: Int? = nil) {
        self.connected = connected
        self.cdcConnected = cdcConnected
        self.adcConnected = adcConnected
        self.updateTime = updateTime
    }
}

struct NIOMaintainStatus: Codable {
    var maintainStatus: Int?
    var currentMaintenanceList: [NIOMaintenanceItem]?
    var sampleTime: Int?

    enum CodingKeys: String, CodingKey {
        case maintainStatus = "maintain_status"
        case currentMaintenanceList = "current_maintenance_list"
        case sampleTime = "sample_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decodeIfPresent(Int.self, forKey: .maintainStatus) {
            maintainStatus = i
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .maintainStatus) {
            maintainStatus = Int(s)
        }
        currentMaintenanceList = try? c.decodeIfPresent([NIOMaintenanceItem].self, forKey: .currentMaintenanceList)
        if let i = try? c.decodeIfPresent(Int.self, forKey: .sampleTime) {
            sampleTime = i
        }
    }

    init(maintainStatus: Int? = nil, currentMaintenanceList: [NIOMaintenanceItem]? = nil, sampleTime: Int? = nil) {
        self.maintainStatus = maintainStatus
        self.currentMaintenanceList = currentMaintenanceList
        self.sampleTime = sampleTime
    }
}

struct NIOMaintenanceItem: Codable {
    var name: String?
    var code: String?
    var isHealthCheck: Bool?

    enum CodingKeys: String, CodingKey {
        case name, code
        case isHealthCheck = "is_health_check"
    }
}

struct NIOExteriorStatus: Codable {
    var vehicleState: Int?
    var mileage: Double?
    var sampleTime: Int?
    var vehlMode: Int?
    var speed: Double?

    enum CodingKeys: String, CodingKey {
        case vehicleState = "vehicle_state"
        case mileage
        case sampleTime = "sample_time"
        case vehlMode = "vehl_mode"
        case speed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decodeIfPresent(Int.self, forKey: .vehicleState) {
            vehicleState = i
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .vehicleState) {
            vehicleState = Int(s)
        }
        if let d = try? c.decodeIfPresent(Double.self, forKey: .mileage) {
            mileage = d
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .mileage) {
            mileage = Double(i)
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .mileage) {
            mileage = Double(s)
        }
        if let i = try? c.decodeIfPresent(Int.self, forKey: .sampleTime) {
            sampleTime = i
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .sampleTime) {
            sampleTime = Int(d)
        }
        if let i = try? c.decodeIfPresent(Int.self, forKey: .vehlMode) {
            vehlMode = i
        }
        if let d = try? c.decodeIfPresent(Double.self, forKey: .speed) {
            speed = d
        } else if let i = try? c.decodeIfPresent(Int.self, forKey: .speed) {
            speed = Double(i)
        }
    }

    init(vehicleState: Int? = nil, mileage: Double? = nil, sampleTime: Int? = nil, vehlMode: Int? = nil, speed: Double? = nil) {
        self.vehicleState = vehicleState
        self.mileage = mileage
        self.sampleTime = sampleTime
        self.vehlMode = vehlMode
        self.speed = speed
    }
}

struct NIOFotaStatus: Codable {
    var lastPartNo: String?
    var lastVersion: String?
    var currentPartNo: String?
    var currentVersion: String?
    var fotaStatus: Int?
    var sampleTime: Int?

    enum CodingKeys: String, CodingKey {
        case lastPartNo = "last_part_no"
        case lastVersion = "last_version"
        case currentPartNo = "current_part_no"
        case currentVersion = "current_version"
        case fotaStatus = "fota_status"
        case sampleTime = "sample_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastPartNo = try? c.decodeIfPresent(String.self, forKey: .lastPartNo)
        lastVersion = try? c.decodeIfPresent(String.self, forKey: .lastVersion)
        currentPartNo = try? c.decodeIfPresent(String.self, forKey: .currentPartNo)
        currentVersion = try? c.decodeIfPresent(String.self, forKey: .currentVersion)
        if let i = try? c.decodeIfPresent(Int.self, forKey: .fotaStatus) {
            fotaStatus = i
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .fotaStatus) {
            fotaStatus = Int(s)
        }
        if let i = try? c.decodeIfPresent(Int.self, forKey: .sampleTime) {
            sampleTime = i
        }
    }

    init(lastPartNo: String? = nil, lastVersion: String? = nil, currentPartNo: String? = nil, currentVersion: String? = nil, fotaStatus: Int? = nil, sampleTime: Int? = nil) {
        self.lastPartNo = lastPartNo
        self.lastVersion = lastVersion
        self.currentPartNo = currentPartNo
        self.currentVersion = currentVersion
        self.fotaStatus = fotaStatus
        self.sampleTime = sampleTime
    }
}

struct NIOSocStatus: Codable {
    var soc: Double?
    var chargeState: Int?
    var maxSoc: Double?
    var remainingRange: Double?
    var remainingActualRange: Double?
    var sampleTime: Int?
    var lockSoc: Double?
    var chargingPower: Double?
    var chargerType: Int?
    var v2lStatus: Int?
    var chargerRealCurA: Double?
    var chargerRealVolV: Double?
    var targetSocPercentage: Double?
    var estimateChargeEndTime: Int?

    enum CodingKeys: String, CodingKey {
        case soc
        case chargeState = "charge_state"
        case maxSoc = "max_soc"
        case remainingRange = "remaining_range"
        case remainingActualRange = "remaining_actual_range"
        case sampleTime = "sample_time"
        case lockSoc = "lock_soc"
        case chargingPower = "charging_power"
        case chargerType = "charger_type"
        case v2lStatus = "v2l_status"
        case chargerRealCurA = "charger_real_cur_a"
        case chargerRealVolV = "charger_real_vol_v"
        case targetSocPercentage = "target_soc_percentage"
        case estimateChargeEndTime = "estimate_charge_end_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func getDouble(_ key: CodingKeys) -> Double? {
            if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
            if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
            if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
            return nil
        }
        func getInt(_ key: CodingKeys) -> Int? {
            if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return i }
            if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return Int(d) }
            if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Int(s) }
            return nil
        }

        soc = getDouble(.soc)
        chargeState = getInt(.chargeState)
        maxSoc = getDouble(.maxSoc)
        remainingRange = getDouble(.remainingRange)
        remainingActualRange = getDouble(.remainingActualRange)
        sampleTime = getInt(.sampleTime)
        lockSoc = getDouble(.lockSoc)
        chargingPower = getDouble(.chargingPower)
        chargerType = getInt(.chargerType)
        v2lStatus = getInt(.v2lStatus)
        chargerRealCurA = getDouble(.chargerRealCurA)
        chargerRealVolV = getDouble(.chargerRealVolV)
        targetSocPercentage = getDouble(.targetSocPercentage)
        estimateChargeEndTime = getInt(.estimateChargeEndTime)
    }

    init(
        soc: Double? = nil,
        chargeState: Int? = nil,
        maxSoc: Double? = nil,
        remainingRange: Double? = nil,
        remainingActualRange: Double? = nil,
        sampleTime: Int? = nil,
        lockSoc: Double? = nil,
        chargingPower: Double? = nil,
        chargerType: Int? = nil,
        v2lStatus: Int? = nil,
        chargerRealCurA: Double? = nil,
        chargerRealVolV: Double? = nil,
        targetSocPercentage: Double? = nil,
        estimateChargeEndTime: Int? = nil
    ) {
        self.soc = soc
        self.chargeState = chargeState
        self.maxSoc = maxSoc
        self.remainingRange = remainingRange
        self.remainingActualRange = remainingActualRange
        self.sampleTime = sampleTime
        self.lockSoc = lockSoc
        self.chargingPower = chargingPower
        self.chargerType = chargerType
        self.v2lStatus = v2lStatus
        self.chargerRealCurA = chargerRealCurA
        self.chargerRealVolV = chargerRealVolV
        self.targetSocPercentage = targetSocPercentage
        self.estimateChargeEndTime = estimateChargeEndTime
    }
}

// MARK: - 通用 JSON 值

enum NIOJSONValue: Codable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([NIOJSONValue])
    case object([String: NIOJSONValue])

    var intValue: Int? {
        switch self {
        case .number(let n): return Int(n)
        case .string(let s): return Int(s)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        case .bool(let b): return b ? 1.0 : 0.0
        default: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .number(let n): return n != 0
        case .string(let s):
            let lower = s.lowercased()
            return lower == "true" || lower == "1" || lower == "yes" || lower == "on"
        default: return nil
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return String(n)
        case .bool(let b): return String(b)
        default: return nil
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int.self) { self = .number(Double(i)); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([NIOJSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: NIOJSONValue].self) { self = .object(o); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    var numberValue: Double? { doubleValue }
    var displayString: String {
        switch self {
        case .null: return "—"
        case .bool(let b): return b ? "是" : "否"
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .string(let s): return s
        case .array: return "[…]"
        case .object: return "{…}"
        }
    }
}

// MARK: - 车辆快照

struct NIOVehicleSnapshot: Codable, Hashable {
    var ts: Int
    var soc: Double
    var range: Double
    var actualRange: Double
    var mileage: Double
    var lat: Double
    var lng: Double
    var insideTemp: Double
    var outsideTemp: Double

    var snapshotKey: String { "\(ts):\(Int(lat * 10000)):\(Int(lng * 10000))" }

    var isValidGPS: Bool {
        NIOVehicleLib.isValidGPS(lat: lat, lng: lng)
    }
}

// MARK: - 换电 / 服务订单

struct NIOServiceOrder: Codable, Identifiable {
    var orderType: String
    var orderName: String?
    var createTime: Int
    var orderStatus: String?
    var orderStatusName: String?
    var orderNo: String?
    var vinCode: String?
    var vehicleId: String?
    var url: String?
    var paymentStatus: String?
    var oipStatus: Int?
    var priceCash: String?
    var payDesc: String?
    var isRight: Bool?
    var resourceAddress: String?
    var pickUpName: String?
    var returnName: String?
    var address: String?
    var cashChooseType: String?
    var extendInfo: [String: NIOJSONValue]?

    var id: String { orderNo ?? "\(createTime)" }

    enum CodingKeys: String, CodingKey {
        case orderType, orderName, createTime, orderStatus, orderStatusName
        case orderNo, vinCode, vehicleId, url, paymentStatus, oipStatus
        case priceCash, payDesc, isRight, resourceAddress, pickUpName, returnName
        case address, cashChooseType, extendInfo
    }
}

struct NIOChangeResponse: Codable {
    var resultCode: String?
    var resultDesc: String?
    var resultData: NIOChangeResultData?
}

struct NIOChangeResultData: Codable {
    var data: [NIOServiceOrder]
    var total: Int?
    var hasMore: Bool?
}

struct NIOTypeStat: Identifiable, Hashable {
    var type: String
    var label: String
    var count: Int
    var spent: Double
    var id: String { type }
}

struct NIOStationStat: Identifiable, Hashable {
    var name: String
    var count: Int
    var spent: Double
    var id: String { name }
}

struct NIOMonthlyStat: Identifiable, Hashable, Codable {
    var id: String { monthKey }
    var monthKey: String      // e.g. "2024-08"
    var label: String         // e.g. "2024 年 8 月"
    var swapCount: Int        // 当月换电次数
    var swapSpent: Double     // 当月换电支出
    var totalOrders: Int      // 当月总服务单数
    var totalSpent: Double    // 当月总支出
}

struct NIOServiceSummary {
    var total: Int
    var byType: [NIOTypeStat]
    var swapCompleted: Int
    var swapCancelled: Int
    var swapSpent: Double
    var swapAvgSpent: Double
    var upgradeCount: Int
    var upgradeCompleted: Int
    var upgradeCancelled: Int
    var upgradeSpent: Double
    var upgradeAvgSpent: Double
    var upgradeDayCount: Int
    var upgradeMonthCount: Int
    var lastOrderTime: Int?
    var topSwapStations: [NIOStationStat]
    var monthlyStats: [NIOMonthlyStat]
    var orders: [NIOServiceOrder]
}

// MARK: - 签到

struct NIOCheckinData: Codable {
    var checkedIn: Bool
    var continuousDays: Int
    var serverTime: Int?
    var requestId: String?

    enum CodingKeys: String, CodingKey {
        case checkedIn = "checked_in"
        case continuousDays = "continuous_days"
        case serverTime = "server_time"
        case requestId = "request_id"
    }
}

// MARK: - 运行日志

struct NIOFetchLogEntry: Identifiable, Codable {
    var id = UUID()
    var category: String
    var level: String
    var message: String
    var detail: String?
    var timestamp: Date
    var requestURL: String?
    var requestMethod: String?
    var requestBody: String?
    var responsePreview: String?
    var statusCode: Int?
}

// MARK: - 状态栏显示字段

enum NIODisplayField: String, Codable, CaseIterable, Identifiable, Sendable {
    case soc, range, actualRange, vehicleState, mileage, orders

    var id: String { rawValue }

    var label: String {
        switch self {
        case .soc: return "电量"
        case .range: return "标准续航"
        case .actualRange: return "实际续航"
        case .vehicleState: return "车辆状态"
        case .mileage: return "总里程"
        case .orders: return "订单数"
        }
    }

    var example: String {
        switch self {
        case .soc: return "85%"
        case .range: return "420km"
        case .actualRange: return "315km"
        case .vehicleState: return "已驻车"
        case .mileage: return "15871km"
        case .orders: return "12单"
        }
    }
}

// MARK: - 每日行驶轨迹模型

struct NIODailyPath: Identifiable, Hashable {
    var day: String              // "YYYY-MM-DD"
    var label: String            // "MM月dd日 周X"
    var points: [NIOVehicleSnapshot]
    var distanceKm: Double
    var startTime: Int
    var endTime: Int

    var id: String { day }
}

struct NIODailyDelta: Identifiable, Hashable {
    var day: String
    var label: String
    var delta: Double
    var id: String { day }
}

// MARK: - 诊断结果模型

struct NIODiagnosticStep: Identifiable {
    let id = UUID()
    let name: String
    let status: StepStatus
    let detail: String

    enum StepStatus {
        case pending, running, success, warning, failure
    }
}

struct NIODiagnosticReport {
    var isRunning = false
    var steps: [NIODiagnosticStep] = []
    var summary: String = ""
    var is403Detected = false
    var recommendation: String = ""
}

// MARK: - 看板卡片定义与元数据

struct NIOCardMeta: Identifiable, Hashable {
    let id: String
    let label: String
    let iconName: String
    let isDefaultVisible: Bool
}

enum NIOCardRegistry {
    static let allCards: [NIOCardMeta] = [
        NIOCardMeta(id: "battery", label: "电池与续航", iconName: "battery.100.bolt", isDefaultVisible: true),
        NIOCardMeta(id: "charging", label: "充电详情", iconName: "bolt.badge.automatic", isDefaultVisible: true),
        NIOCardMeta(id: "doors_visual", label: "车门状态", iconName: "car.side.front.open", isDefaultVisible: true),
        NIOCardMeta(id: "window", label: "车窗与后视镜", iconName: "car.side.window.open", isDefaultVisible: true),
        NIOCardMeta(id: "tyre", label: "轮胎胎压胎温", iconName: "circle.grid.2x2", isDefaultVisible: true),
        NIOCardMeta(id: "modes", label: "特殊模式", iconName: "pawprint.fill", isDefaultVisible: true),
        NIOCardMeta(id: "seat_heat", label: "座椅加热与空调", iconName: "flame.fill", isDefaultVisible: true),
        NIOCardMeta(id: "vehicle_info", label: "车辆基本信息", iconName: "car.fill", isDefaultVisible: true),
        NIOCardMeta(id: "exterior_detail", label: "行驶与泊车", iconName: "steeringwheel", isDefaultVisible: true),
        NIOCardMeta(id: "software_gps", label: "软件版本与GPS", iconName: "location.fill", isDefaultVisible: true),
        NIOCardMeta(id: "connection", label: "连接与在线状态", iconName: "wifi", isDefaultVisible: true),
        NIOCardMeta(id: "temperature", label: "座舱温度与空调", iconName: "thermometer.medium", isDefaultVisible: true),
        NIOCardMeta(id: "maintain", label: "维保状态", iconName: "wrench.and.screwdriver.fill", isDefaultVisible: true),
        NIOCardMeta(id: "light", label: "车灯照明", iconName: "light.beacon.max", isDefaultVisible: true),
        NIOCardMeta(id: "key", label: "钥匙与近车", iconName: "key.fill", isDefaultVisible: true),
        NIOCardMeta(id: "special", label: "特殊状态", iconName: "exclamationmark.triangle", isDefaultVisible: false),
        NIOCardMeta(id: "lv_batt", label: "低压电瓶", iconName: "battery.50", isDefaultVisible: false),
        NIOCardMeta(id: "box", label: "储物箱与冰箱", iconName: "shippingbox.fill", isDefaultVisible: false),
    ]
}
