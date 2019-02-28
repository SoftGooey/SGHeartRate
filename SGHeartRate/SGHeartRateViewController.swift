//
//  SGHeartRateViewController.swift
//  SGHeartRate
//
//  Created by Sophie Prince on 2019-02-26.
//  Copyright © 2019 SoftGooey. All rights reserved.
//
//  This view controller registers to CoreBluetooth and displays
//  the device name, battery level, latest heart rate and graphs
//  the heart rate
//

import UIKit
import CoreBluetooth
import Charts

let deviceInfoServiceCBUUID = CBUUID(string: "0x180A")
let deviceManufacturerNameCBUUID = CBUUID(string: "0x2A29")
let deviceModelNumberCBUUID = CBUUID(string: "0x2A24")

let batteryServiceCBUUID = CBUUID(string: "0x180F")
let batteryLevelCBUUID = CBUUID(string: "0x2A19")

let heartRateServiceCBUUID = CBUUID(string: "0x180D")
let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37")
let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "2A38")


class SGHeartRateViewController: UIViewController {

    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var batteryLevelLabel: UILabel!
    @IBOutlet weak var latestHeartRateLabel: UILabel!
    @IBOutlet weak var lineChartView: LineChartView!
    
    var centralManager: CBCentralManager!
    var heartRatePeripheral: CBPeripheral!
    var lineChartDataSet = LineChartDataSet()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        lineChartView.xAxis.drawLabelsEnabled = false
        lineChartDataSet.lineWidth = 2
        lineChartDataSet.circleRadius = 3
        lineChartDataSet.label = NSLocalizedString("beatsPerMinute", comment: "")
        lineChartDataSet.setCircleColor(UIColor.red)
        lineChartDataSet.colors = [UIColor.red]
        lineChartDataSet.drawValuesEnabled = false
    }
    
    func onHeartRateReceived(_ heartRate: Int) {
        latestHeartRateLabel.text = String(heartRate)
        if heartRate > 0 {
            let entry = ChartDataEntry(x: Double(lineChartDataSet.count), y: Double(heartRate))
            lineChartDataSet.append(entry)
            let lineChartData = LineChartData(dataSet: lineChartDataSet)
            lineChartView.data = lineChartData
        }
        print("BPM: \(heartRate)")
    }
    
    func onBatteryLevelReceived(_ batteryLevel: Int) {
        batteryLevelLabel.text = String.init(format: "%d %%", batteryLevel)
    }
    
    func onDeviceNameReceived(_ deviceName: String?) {
        if deviceName != nil {
            deviceNameLabel.text = deviceName
        }
    }
}

extension SGHeartRateViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
            let message = String.init(format: NSLocalizedString("bleUnsupported", comment: ""), UIDevice.current.model)
            let alert = UIAlertController(title: NSLocalizedString("Warning", comment: ""), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
            let message = String.init(format: NSLocalizedString("bleTurnedOff", comment: ""), UIDevice.current.model)
            let alert = UIAlertController(title: NSLocalizedString("Warning", comment: ""), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Ok", comment: ""), style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        case .poweredOn:
            print("central.state is .poweredOn")
            centralManager.scanForPeripherals(withServices: [deviceInfoServiceCBUUID, heartRateServiceCBUUID, batteryServiceCBUUID])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        heartRatePeripheral = peripheral
        heartRatePeripheral.delegate = self
        centralManager.stopScan()
        centralManager.connect(heartRatePeripheral)
        onDeviceNameReceived(peripheral.name)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        heartRatePeripheral.discoverServices([deviceInfoServiceCBUUID, heartRateServiceCBUUID, batteryServiceCBUUID])
    }
}

extension SGHeartRateViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print(service)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print(characteristic)
            
            if characteristic.properties.contains(.read) {
                print("\(characteristic.uuid): properties contains .read")
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) {
                print("\(characteristic.uuid): properties contains .notify")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case bodySensorLocationCharacteristicCBUUID:
            let bodySensorLocation = bodyLocation(from: characteristic)
            print(bodySensorLocation)
        case heartRateMeasurementCharacteristicCBUUID:
            let bpm = heartRate(from: characteristic)
            onHeartRateReceived(bpm)
        case batteryLevelCBUUID:
            let batteryLev = batteryLevel(from: characteristic)
            onBatteryLevelReceived(batteryLev)
        case deviceManufacturerNameCBUUID:
            let manufacturerName = deviceName(from: characteristic)
            print(manufacturerName)
        case deviceModelNumberCBUUID:
            let modelNumber = deviceName(from: characteristic)
            print(modelNumber)
        default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
    
    private func bodyLocation(from characteristic: CBCharacteristic) -> String {
        guard let characteristicData = characteristic.value,
            let byte = characteristicData.first else { return "Error" }
        
        // See https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.body_sensor_location.xml
        switch byte {
        case 0: return "Other"
        case 1: return "Chest"
        case 2: return "Wrist"
        case 3: return "Finger"
        case 4: return "Hand"
        case 5: return "Ear Lobe"
        case 6: return "Foot"
        default:
            return "Reserved for future use"
        }
    }
    
    private func heartRate(from characteristic: CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value else { return -1 }
        let byteArray = [UInt8](characteristicData)
        
        // See: https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.heart_rate_measurement.xml
        // The heart rate mesurement is in the 2nd, or in the 2nd and 3rd bytes, i.e. one one or in two bytes
        // The first byte of the first bit specifies the length of the heart rate data, 0 == 1 byte, 1 == 2 bytes
        let firstBitValue = byteArray[0] & 0x01
        if firstBitValue == 0 {
            // Heart Rate Value Format is in the 2nd byte
            return Int(byteArray[1])
        } else {
            // Heart Rate Value Format is in the 2nd and 3rd bytes
            return (Int(byteArray[1]) << 8) + Int(byteArray[2])
        }
    }
    
    private func batteryLevel(from characteristic: CBCharacteristic) -> Int {
        guard let characteristicData = characteristic.value else { return -1 }
        let byteArray = [UInt8](characteristicData)

        // See: https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.battery_level.xml
        // battery level is a value from 0 to 100
        return Int(byteArray[0])
    }
    
    private func deviceName(from characteristic: CBCharacteristic) -> String {
        guard let characteristicData = characteristic.value else { return "" }
        
        // Ascii?  Should it be UTF8 ?
        guard let name = String(data: characteristicData, encoding: String.Encoding.ascii) else { return "" }
        return name
    }
}

