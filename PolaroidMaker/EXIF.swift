//
//  EXIF.swift
//  PolaroidMaker
//
//  Created by Vlad Ungureanu on 08/09/2025.
//

import Foundation
import Photos
import CoreLocation

struct EXIFHelper {
    static func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: date)
    }
    
    static func formatDate(for asset: PHAsset) -> String {
        return formatDate(asset.creationDate)
    }
    
    static func makeDefaultCaption(for asset: PHAsset) async -> String {
        let dateString = formatDate(asset.creationDate)
        
        if let location = asset.location {
            let locationString = await Geo.reverseGeocode(location: location)
            if !locationString.isEmpty {
                return "\(dateString) — \(locationString)"
            }
        }
        
        return dateString
    }
    
    static func extractLocation(from asset: PHAsset) -> CLLocation? {
        return asset.location
    }
    
    static func extractCreationDate(from asset: PHAsset) -> Date? {
        return asset.creationDate
    }
    
    static func formatLocationString(city: String?, country: String?) -> String {
        let shortCountry = country.map { getCountryCode($0) } ?? country
        
        switch (city, shortCountry) {
        case let (city?, country?) where !city.isEmpty && !country.isEmpty:
            return "\(city), \(country)"
        case let (city?, _) where !city.isEmpty:
            return city
        case let (_, country?) where !country.isEmpty:
            return country
        default:
            return ""
        }
    }
    
    private static func getCountryCode(_ countryName: String) -> String {
        let countryMappings: [String: String] = [
            "Romania": "Ro",
            "France": "Fr",
            "United Kingdom": "UK",
            "Italy": "It",
            "Germany": "DE",
            "Spain": "Es",
            "Portugal": "PT",
            "Netherlands": "NL",
            "Belgium": "BE",
            "Switzerland": "CH",
            "Austria": "AT",
            "Poland": "PL",
            "Czech Republic": "CZ",
            "Slovakia": "SK",
            "Hungary": "HU",
            "Croatia": "HR",
            "Slovenia": "SI",
            "Serbia": "RS",
            "Bulgaria": "BG",
            "Greece": "GR",
            "Cyprus": "CY",
            "Malta": "MT",
            "Ireland": "IE",
            "Denmark": "DK",
            "Sweden": "SE",
            "Norway": "NO",
            "Finland": "FI",
            "Iceland": "IS",
            "Estonia": "EE",
            "Latvia": "LV",
            "Lithuania": "LT",
            "Luxembourg": "LU",
            "Monaco": "MC",
            "Andorra": "AD",
            "Liechtenstein": "LI",
            "San Marino": "SM",
            "Vatican City": "VA",
            "United States": "US",
            "Canada": "CA",
            "Mexico": "MX",
            "Brazil": "BR",
            "Argentina": "AR",
            "Chile": "CL",
            "Colombia": "CO",
            "Peru": "PE",
            "Venezuela": "VE",
            "Ecuador": "EC",
            "Bolivia": "BO",
            "Paraguay": "PY",
            "Uruguay": "UY",
            "Guyana": "GY",
            "Suriname": "SR",
            "Japan": "JP",
            "China": "CN",
            "South Korea": "KR",
            "North Korea": "KP",
            "India": "IN",
            "Pakistan": "PK",
            "Bangladesh": "BD",
            "Sri Lanka": "LK",
            "Nepal": "NP",
            "Bhutan": "BT",
            "Maldives": "MV",
            "Afghanistan": "AF",
            "Iran": "IR",
            "Iraq": "IQ",
            "Turkey": "TR",
            "Syria": "SY",
            "Lebanon": "LB",
            "Jordan": "JO",
            "Israel": "IL",
            "Palestine": "PS",
            "Saudi Arabia": "SA",
            "Yemen": "YE",
            "Oman": "OM",
            "United Arab Emirates": "AE",
            "Qatar": "QA",
            "Bahrain": "BH",
            "Kuwait": "KW",
            "Egypt": "EG",
            "Libya": "LY",
            "Tunisia": "TN",
            "Algeria": "DZ",
            "Morocco": "MA",
            "Sudan": "SD",
            "South Sudan": "SS",
            "Ethiopia": "ET",
            "Eritrea": "ER",
            "Djibouti": "DJ",
            "Somalia": "SO",
            "Kenya": "KE",
            "Uganda": "UG",
            "Tanzania": "TZ",
            "Rwanda": "RW",
            "Burundi": "BI",
            "Democratic Republic of the Congo": "CD",
            "Republic of the Congo": "CG",
            "Central African Republic": "CF",
            "Chad": "TD",
            "Cameroon": "CM",
            "Equatorial Guinea": "GQ",
            "Gabon": "GA",
            "São Tomé and Príncipe": "ST",
            "Nigeria": "NG",
            "Niger": "NE",
            "Burkina Faso": "BF",
            "Mali": "ML",
            "Senegal": "SN",
            "Mauritania": "MR",
            "Guinea": "GN",
            "Guinea-Bissau": "GW",
            "Sierra Leone": "SL",
            "Liberia": "LR",
            "Ivory Coast": "CI",
            "Ghana": "GH",
            "Togo": "TG",
            "Benin": "BJ",
            "South Africa": "ZA",
            "Namibia": "NA",
            "Botswana": "BW",
            "Zimbabwe": "ZW",
            "Zambia": "ZM",
            "Malawi": "MW",
            "Mozambique": "MZ",
            "Swaziland": "SZ",
            "Lesotho": "LS",
            "Madagascar": "MG",
            "Mauritius": "MU",
            "Seychelles": "SC",
            "Comoros": "KM",
            "Cape Verde": "CV",
            "Australia": "AU",
            "New Zealand": "NZ",
            "Papua New Guinea": "PG",
            "Fiji": "FJ",
            "Solomon Islands": "SB",
            "Vanuatu": "VU",
            "New Caledonia": "NC",
            "French Polynesia": "PF",
            "Samoa": "WS",
            "Tonga": "TO",
            "Kiribati": "KI",
            "Tuvalu": "TV",
            "Nauru": "NR",
            "Palau": "PW",
            "Marshall Islands": "MH",
            "Micronesia": "FM",
            "Russia": "RU",
            "Kazakhstan": "KZ",
            "Uzbekistan": "UZ",
            "Turkmenistan": "TM",
            "Kyrgyzstan": "KG",
            "Tajikistan": "TJ",
            "Mongolia": "MN",
            "Belarus": "BY",
            "Ukraine": "UA",
            "Moldova": "MD",
            "Georgia": "GE",
            "Armenia": "AM",
            "Azerbaijan": "AZ",
            "Albania": "AL",
            "Montenegro": "ME",
            "Bosnia and Herzegovina": "BA",
            "North Macedonia": "MK",
            "Kosovo": "XK",
            "Thailand": "TH",
            "Vietnam": "VN",
            "Laos": "LA",
            "Cambodia": "KH",
            "Myanmar": "MM",
            "Malaysia": "MY",
            "Singapore": "SG",
            "Indonesia": "ID",
            "Brunei": "BN",
            "Philippines": "PH",
            "East Timor": "TL"
        ]
        
        return countryMappings[countryName] ?? countryName
    }
}
