//
//  StatusBarView.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/23.
//

import SwiftUI

struct StatusBarView: View {
    @ObservedObject var statusDataModel = SharedStore.statusDataModel
    
    var body: some View {
        HStack {
            Text("↕").font(.system(size: 19))
                            .frame(width: 20, height: 20, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
            
            VStack(spacing: 0) {
                Spacer().frame(width: 0, height: 1, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
                HStack {
                    Text(formatBytes(bytes: statusDataModel.totalOutBytes))
                        .padding(-7.0).font(.system(size: 11))
                }.frame(width:45, height: 12, alignment: .leading)
                HStack {
                    Text(formatBytes(bytes: statusDataModel.totalInBytes))
                        .padding(-7.0).font(.system(size: 11))
                }.padding(.top, -1.5).frame(width:45, height: 12, alignment: .leading)
            }
        }
    }
}

struct StatusBarView_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarView()
    }
}
