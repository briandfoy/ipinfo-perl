package Geo::IPinfo;

use 5.006;
use strict;
use warnings;
use Cache::LRU;
use LWP::UserAgent;
use HTTP::Headers;
use JSON;
use Geo::Details;
use Net::CIDR;
use Net::CIDR::Set;

our $VERSION = '3.0.2';
use constant DEFAULT_CACHE_MAX_SIZE => 4096;
use constant DEFAULT_CACHE_TTL      => 86_400;
use constant DEFAULT_TIMEOUT        => 2;
use constant HTTP_TOO_MANY_REQUEST  => 429;

my %valid_fields = (
    ip       => 1,
    hostname => 1,
    city     => 1,
    region   => 1,
    country  => 1,
    loc      => 1,
    org      => 1,
    postal   => 1,
    timezone => 1,
    geo      => 1,
    asn      => 1,
    company  => 1,
    privacy  => 1,
    abuse    => 1,
    domains  => 1,
);
my $base_url          = 'https://ipinfo.io/';
my $base_url_ipv6     = 'https://v6.ipinfo.io/';
my $country_flag_url  = 'https://cdn.ipinfo.io/static/images/countries-flags/';
my $cache_ttl    = 0;
my $custom_cache = 0;
my %default_countries = (
    "BD" => "Bangladesh",
    "BE" => "Belgium",
    "BF" => "Burkina Faso",
    "BG" => "Bulgaria",
    "BA" => "Bosnia and Herzegovina",
    "BB" => "Barbados",
    "WF" => "Wallis and Futuna",
    "BL" => "Saint Barthelemy",
    "BM" => "Bermuda",
    "BN" => "Brunei",
    "BO" => "Bolivia",
    "BH" => "Bahrain",
    "BI" => "Burundi",
    "BJ" => "Benin",
    "BT" => "Bhutan",
    "JM" => "Jamaica",
    "BV" => "Bouvet Island",
    "BW" => "Botswana",
    "WS" => "Samoa",
    "BQ" => "Bonaire, Saint Eustatius and Saba ",
    "BR" => "Brazil",
    "BS" => "Bahamas",
    "JE" => "Jersey",
    "BY" => "Belarus",
    "BZ" => "Belize",
    "RU" => "Russia",
    "RW" => "Rwanda",
    "RS" => "Serbia",
    "TL" => "East Timor",
    "RE" => "Reunion",
    "TM" => "Turkmenistan",
    "TJ" => "Tajikistan",
    "RO" => "Romania",
    "TK" => "Tokelau",
    "GW" => "Guinea-Bissau",
    "GU" => "Guam",
    "GT" => "Guatemala",
    "GS" => "South Georgia and the South Sandwich Islands",
    "GR" => "Greece",
    "GQ" => "Equatorial Guinea",
    "GP" => "Guadeloupe",
    "JP" => "Japan",
    "GY" => "Guyana",
    "GG" => "Guernsey",
    "GF" => "French Guiana",
    "GE" => "Georgia",
    "GD" => "Grenada",
    "GB" => "United Kingdom",
    "GA" => "Gabon",
    "SV" => "El Salvador",
    "GN" => "Guinea",
    "GM" => "Gambia",
    "GL" => "Greenland",
    "GI" => "Gibraltar",
    "GH" => "Ghana",
    "OM" => "Oman",
    "TN" => "Tunisia",
    "JO" => "Jordan",
    "HR" => "Croatia",
    "HT" => "Haiti",
    "HU" => "Hungary",
    "HK" => "Hong Kong",
    "HN" => "Honduras",
    "HM" => "Heard Island and McDonald Islands",
    "VE" => "Venezuela",
    "PR" => "Puerto Rico",
    "PS" => "Palestinian Territory",
    "PW" => "Palau",
    "PT" => "Portugal",
    "SJ" => "Svalbard and Jan Mayen",
    "PY" => "Paraguay",
    "IQ" => "Iraq",
    "PA" => "Panama",
    "PF" => "French Polynesia",
    "PG" => "Papua New Guinea",
    "PE" => "Peru",
    "PK" => "Pakistan",
    "PH" => "Philippines",
    "PN" => "Pitcairn",
    "PL" => "Poland",
    "PM" => "Saint Pierre and Miquelon",
    "ZM" => "Zambia",
    "EH" => "Western Sahara",
    "EE" => "Estonia",
    "EG" => "Egypt",
    "ZA" => "South Africa",
    "EC" => "Ecuador",
    "IT" => "Italy",
    "VN" => "Vietnam",
    "SB" => "Solomon Islands",
    "ET" => "Ethiopia",
    "SO" => "Somalia",
    "ZW" => "Zimbabwe",
    "SA" => "Saudi Arabia",
    "ES" => "Spain",
    "ER" => "Eritrea",
    "ME" => "Montenegro",
    "MD" => "Moldova",
    "MG" => "Madagascar",
    "MF" => "Saint Martin",
    "MA" => "Morocco",
    "MC" => "Monaco",
    "UZ" => "Uzbekistan",
    "MM" => "Myanmar",
    "ML" => "Mali",
    "MO" => "Macao",
    "MN" => "Mongolia",
    "MH" => "Marshall Islands",
    "MK" => "Macedonia",
    "MU" => "Mauritius",
    "MT" => "Malta",
    "MW" => "Malawi",
    "MV" => "Maldives",
    "MQ" => "Martinique",
    "MP" => "Northern Mariana Islands",
    "MS" => "Montserrat",
    "MR" => "Mauritania",
    "IM" => "Isle of Man",
    "UG" => "Uganda",
    "TZ" => "Tanzania",
    "MY" => "Malaysia",
    "MX" => "Mexico",
    "IL" => "Israel",
    "FR" => "France",
    "IO" => "British Indian Ocean Territory",
    "SH" => "Saint Helena",
    "FI" => "Finland",
    "FJ" => "Fiji",
    "FK" => "Falkland Islands",
    "FM" => "Micronesia",
    "FO" => "Faroe Islands",
    "NI" => "Nicaragua",
    "NL" => "Netherlands",
    "NO" => "Norway",
    "NA" => "Namibia",
    "VU" => "Vanuatu",
    "NC" => "New Caledonia",
    "NE" => "Niger",
    "NF" => "Norfolk Island",
    "NG" => "Nigeria",
    "NZ" => "New Zealand",
    "NP" => "Nepal",
    "NR" => "Nauru",
    "NU" => "Niue",
    "CK" => "Cook Islands",
    "XK" => "Kosovo",
    "CI" => "Ivory Coast",
    "CH" => "Switzerland",
    "CO" => "Colombia",
    "CN" => "China",
    "CM" => "Cameroon",
    "CL" => "Chile",
    "CC" => "Cocos Islands",
    "CA" => "Canada",
    "CG" => "Republic of the Congo",
    "CF" => "Central African Republic",
    "CD" => "Democratic Republic of the Congo",
    "CZ" => "Czech Republic",
    "CY" => "Cyprus",
    "CX" => "Christmas Island",
    "CR" => "Costa Rica",
    "CW" => "Curacao",
    "CV" => "Cape Verde",
    "CU" => "Cuba",
    "SZ" => "Swaziland",
    "SY" => "Syria",
    "SX" => "Sint Maarten",
    "KG" => "Kyrgyzstan",
    "KE" => "Kenya",
    "SS" => "South Sudan",
    "SR" => "Suriname",
    "KI" => "Kiribati",
    "KH" => "Cambodia",
    "KN" => "Saint Kitts and Nevis",
    "KM" => "Comoros",
    "ST" => "Sao Tome and Principe",
    "SK" => "Slovakia",
    "KR" => "South Korea",
    "SI" => "Slovenia",
    "KP" => "North Korea",
    "KW" => "Kuwait",
    "SN" => "Senegal",
    "SM" => "San Marino",
    "SL" => "Sierra Leone",
    "SC" => "Seychelles",
    "KZ" => "Kazakhstan",
    "KY" => "Cayman Islands",
    "SG" => "Singapore",
    "SE" => "Sweden",
    "SD" => "Sudan",
    "DO" => "Dominican Republic",
    "DM" => "Dominica",
    "DJ" => "Djibouti",
    "DK" => "Denmark",
    "VG" => "British Virgin Islands",
    "DE" => "Germany",
    "YE" => "Yemen",
    "DZ" => "Algeria",
    "US" => "United States",
    "UY" => "Uruguay",
    "YT" => "Mayotte",
    "UM" => "United States Minor Outlying Islands",
    "LB" => "Lebanon",
    "LC" => "Saint Lucia",
    "LA" => "Laos",
    "TV" => "Tuvalu",
    "TW" => "Taiwan",
    "TT" => "Trinidad and Tobago",
    "TR" => "Turkey",
    "LK" => "Sri Lanka",
    "LI" => "Liechtenstein",
    "LV" => "Latvia",
    "TO" => "Tonga",
    "LT" => "Lithuania",
    "LU" => "Luxembourg",
    "LR" => "Liberia",
    "LS" => "Lesotho",
    "TH" => "Thailand",
    "TF" => "French Southern Territories",
    "TG" => "Togo",
    "TD" => "Chad",
    "TC" => "Turks and Caicos Islands",
    "LY" => "Libya",
    "VA" => "Vatican",
    "VC" => "Saint Vincent and the Grenadines",
    "AE" => "United Arab Emirates",
    "AD" => "Andorra",
    "AG" => "Antigua and Barbuda",
    "AF" => "Afghanistan",
    "AI" => "Anguilla",
    "VI" => "U.S. Virgin Islands",
    "IS" => "Iceland",
    "IR" => "Iran",
    "AM" => "Armenia",
    "AL" => "Albania",
    "AO" => "Angola",
    "AQ" => "Antarctica",
    "AS" => "American Samoa",
    "AR" => "Argentina",
    "AU" => "Australia",
    "AT" => "Austria",
    "AW" => "Aruba",
    "IN" => "India",
    "AX" => "Aland Islands",
    "AZ" => "Azerbaijan",
    "IE" => "Ireland",
    "ID" => "Indonesia",
    "UA" => "Ukraine",
    "QA" => "Qatar",
    "MZ" => "Mozambique"
);
my %default_countries_flags = (
    'AD' => { 'emoji' => '🇦🇩', 'unicode' => 'U+1F1E6 U+1F1E9' },
    'AE' => { 'emoji' => '🇦🇪', 'unicode' => 'U+1F1E6 U+1F1EA' },
    'AF' => { 'emoji' => '🇦🇫', 'unicode' => 'U+1F1E6 U+1F1EB' },
    'AG' => { 'emoji' => '🇦🇬', 'unicode' => 'U+1F1E6 U+1F1EC' },
    'AI' => { 'emoji' => '🇦🇮', 'unicode' => 'U+1F1E6 U+1F1EE' },
    'AL' => { 'emoji' => '🇦🇱', 'unicode' => 'U+1F1E6 U+1F1F1' },
    'AM' => { 'emoji' => '🇦🇲', 'unicode' => 'U+1F1E6 U+1F1F2' },
    'AO' => { 'emoji' => '🇦🇴', 'unicode' => 'U+1F1E6 U+1F1F4' },
    'AQ' => { 'emoji' => '🇦🇶', 'unicode' => 'U+1F1E6 U+1F1F6' },
    'AR' => { 'emoji' => '🇦🇷', 'unicode' => 'U+1F1E6 U+1F1F7' },
    'AS' => { 'emoji' => '🇦🇸', 'unicode' => 'U+1F1E6 U+1F1F8' },
    'AT' => { 'emoji' => '🇦🇹', 'unicode' => 'U+1F1E6 U+1F1F9' },
    'AU' => { 'emoji' => '🇦🇺', 'unicode' => 'U+1F1E6 U+1F1FA' },
    'AW' => { 'emoji' => '🇦🇼', 'unicode' => 'U+1F1E6 U+1F1FC' },
    'AX' => { 'emoji' => '🇦🇽', 'unicode' => 'U+1F1E6 U+1F1FD' },
    'AZ' => { 'emoji' => '🇦🇿', 'unicode' => 'U+1F1E6 U+1F1FF' },
    'BA' => { 'emoji' => '🇧🇦', 'unicode' => 'U+1F1E7 U+1F1E6' },
    'BB' => { 'emoji' => '🇧🇧', 'unicode' => 'U+1F1E7 U+1F1E7' },
    'BD' => { 'emoji' => '🇧🇩', 'unicode' => 'U+1F1E7 U+1F1E9' },
    'BE' => { 'emoji' => '🇧🇪', 'unicode' => 'U+1F1E7 U+1F1EA' },
    'BF' => { 'emoji' => '🇧🇫', 'unicode' => 'U+1F1E7 U+1F1EB' },
    'BG' => { 'emoji' => '🇧🇬', 'unicode' => 'U+1F1E7 U+1F1EC' },
    'BH' => { 'emoji' => '🇧🇭', 'unicode' => 'U+1F1E7 U+1F1ED' },
    'BI' => { 'emoji' => '🇧🇮', 'unicode' => 'U+1F1E7 U+1F1EE' },
    'BJ' => { 'emoji' => '🇧🇯', 'unicode' => 'U+1F1E7 U+1F1EF' },
    'BL' => { 'emoji' => '🇧🇱', 'unicode' => 'U+1F1E7 U+1F1F1' },
    'BM' => { 'emoji' => '🇧🇲', 'unicode' => 'U+1F1E7 U+1F1F2' },
    'BN' => { 'emoji' => '🇧🇳', 'unicode' => 'U+1F1E7 U+1F1F3' },
    'BO' => { 'emoji' => '🇧🇴', 'unicode' => 'U+1F1E7 U+1F1F4' },
    'BQ' => { 'emoji' => '🇧🇶', 'unicode' => 'U+1F1E7 U+1F1F6' },
    'BR' => { 'emoji' => '🇧🇷', 'unicode' => 'U+1F1E7 U+1F1F7' },
    'BS' => { 'emoji' => '🇧🇸', 'unicode' => 'U+1F1E7 U+1F1F8' },
    'BT' => { 'emoji' => '🇧🇹', 'unicode' => 'U+1F1E7 U+1F1F9' },
    'BV' => { 'emoji' => '🇧🇻', 'unicode' => 'U+1F1E7 U+1F1FB' },
    'BW' => { 'emoji' => '🇧🇼', 'unicode' => 'U+1F1E7 U+1F1FC' },
    'BY' => { 'emoji' => '🇧🇾', 'unicode' => 'U+1F1E7 U+1F1FE' },
    'BZ' => { 'emoji' => '🇧🇿', 'unicode' => 'U+1F1E7 U+1F1FF' },
    'CA' => { 'emoji' => '🇨🇦', 'unicode' => 'U+1F1E8 U+1F1E6' },
    'CC' => { 'emoji' => '🇨🇨', 'unicode' => 'U+1F1E8 U+1F1E8' },
    'CD' => { 'emoji' => '🇨🇩', 'unicode' => 'U+1F1E8 U+1F1E9' },
    'CF' => { 'emoji' => '🇨🇫', 'unicode' => 'U+1F1E8 U+1F1EB' },
    'CG' => { 'emoji' => '🇨🇬', 'unicode' => 'U+1F1E8 U+1F1EC' },
    'CH' => { 'emoji' => '🇨🇭', 'unicode' => 'U+1F1E8 U+1F1ED' },
    'CI' => { 'emoji' => '🇨🇮', 'unicode' => 'U+1F1E8 U+1F1EE' },
    'CK' => { 'emoji' => '🇨🇰', 'unicode' => 'U+1F1E8 U+1F1F0' },
    'CL' => { 'emoji' => '🇨🇱', 'unicode' => 'U+1F1E8 U+1F1F1' },
    'CM' => { 'emoji' => '🇨🇲', 'unicode' => 'U+1F1E8 U+1F1F2' },
    'CN' => { 'emoji' => '🇨🇳', 'unicode' => 'U+1F1E8 U+1F1F3' },
    'CO' => { 'emoji' => '🇨🇴', 'unicode' => 'U+1F1E8 U+1F1F4' },
    'CR' => { 'emoji' => '🇨🇷', 'unicode' => 'U+1F1E8 U+1F1F7' },
    'CU' => { 'emoji' => '🇨🇺', 'unicode' => 'U+1F1E8 U+1F1FA' },
    'CV' => { 'emoji' => '🇨🇻', 'unicode' => 'U+1F1E8 U+1F1FB' },
    'CW' => { 'emoji' => '🇨🇼', 'unicode' => 'U+1F1E8 U+1F1FC' },
    'CX' => { 'emoji' => '🇨🇽', 'unicode' => 'U+1F1E8 U+1F1FD' },
    'CY' => { 'emoji' => '🇨🇾', 'unicode' => 'U+1F1E8 U+1F1FE' },
    'CZ' => { 'emoji' => '🇨🇿', 'unicode' => 'U+1F1E8 U+1F1FF' },
    'DE' => { 'emoji' => '🇩🇪', 'unicode' => 'U+1F1E9 U+1F1EA' },
    'DJ' => { 'emoji' => '🇩🇯', 'unicode' => 'U+1F1E9 U+1F1EF' },
    'DK' => { 'emoji' => '🇩🇰', 'unicode' => 'U+1F1E9 U+1F1F0' },
    'DM' => { 'emoji' => '🇩🇲', 'unicode' => 'U+1F1E9 U+1F1F2' },
    'DO' => { 'emoji' => '🇩🇴', 'unicode' => 'U+1F1E9 U+1F1F4' },
    'DZ' => { 'emoji' => '🇩🇿', 'unicode' => 'U+1F1E9 U+1F1FF' },
    'EC' => { 'emoji' => '🇪🇨', 'unicode' => 'U+1F1EA U+1F1E8' },
    'EE' => { 'emoji' => '🇪🇪', 'unicode' => 'U+1F1EA U+1F1EA' },
    'EG' => { 'emoji' => '🇪🇬', 'unicode' => 'U+1F1EA U+1F1EC' },
    'EH' => { 'emoji' => '🇪🇭', 'unicode' => 'U+1F1EA U+1F1ED' },
    'ER' => { 'emoji' => '🇪🇷', 'unicode' => 'U+1F1EA U+1F1F7' },
    'ES' => { 'emoji' => '🇪🇸', 'unicode' => 'U+1F1EA U+1F1F8' },
    'ET' => { 'emoji' => '🇪🇹', 'unicode' => 'U+1F1EA U+1F1F9' },
    'FI' => { 'emoji' => '🇫🇮', 'unicode' => 'U+1F1EB U+1F1EE' },
    'FJ' => { 'emoji' => '🇫🇯', 'unicode' => 'U+1F1EB U+1F1EF' },
    'FK' => { 'emoji' => '🇫🇰', 'unicode' => 'U+1F1EB U+1F1F0' },
    'FM' => { 'emoji' => '🇫🇲', 'unicode' => 'U+1F1EB U+1F1F2' },
    'FO' => { 'emoji' => '🇫🇴', 'unicode' => 'U+1F1EB U+1F1F4' },
    'FR' => { 'emoji' => '🇫🇷', 'unicode' => 'U+1F1EB U+1F1F7' },
    'GA' => { 'emoji' => '🇬🇦', 'unicode' => 'U+1F1EC U+1F1E6' },
    'GB' => { 'emoji' => '🇬🇧', 'unicode' => 'U+1F1EC U+1F1E7' },
    'GD' => { 'emoji' => '🇬🇩', 'unicode' => 'U+1F1EC U+1F1E9' },
    'GE' => { 'emoji' => '🇬🇪', 'unicode' => 'U+1F1EC U+1F1EA' },
    'GF' => { 'emoji' => '🇬🇫', 'unicode' => 'U+1F1EC U+1F1EB' },
    'GG' => { 'emoji' => '🇬🇬', 'unicode' => 'U+1F1EC U+1F1EC' },
    'GH' => { 'emoji' => '🇬🇭', 'unicode' => 'U+1F1EC U+1F1ED' },
    'GI' => { 'emoji' => '🇬🇮', 'unicode' => 'U+1F1EC U+1F1EE' },
    'GL' => { 'emoji' => '🇬🇱', 'unicode' => 'U+1F1EC U+1F1F1' },
    'GM' => { 'emoji' => '🇬🇲', 'unicode' => 'U+1F1EC U+1F1F2' },
    'GN' => { 'emoji' => '🇬🇳', 'unicode' => 'U+1F1EC U+1F1F3' },
    'GP' => { 'emoji' => '🇬🇵', 'unicode' => 'U+1F1EC U+1F1F5' },
    'GQ' => { 'emoji' => '🇬🇶', 'unicode' => 'U+1F1EC U+1F1F6' },
    'GR' => { 'emoji' => '🇬🇷', 'unicode' => 'U+1F1EC U+1F1F7' },
    'GS' => { 'emoji' => '🇬🇸', 'unicode' => 'U+1F1EC U+1F1F8' },
    'GT' => { 'emoji' => '🇬🇹', 'unicode' => 'U+1F1EC U+1F1F9' },
    'GU' => { 'emoji' => '🇬🇺', 'unicode' => 'U+1F1EC U+1F1FA' },
    'GW' => { 'emoji' => '🇬🇼', 'unicode' => 'U+1F1EC U+1F1FC' },
    'GY' => { 'emoji' => '🇬🇾', 'unicode' => 'U+1F1EC U+1F1FE' },
    'HK' => { 'emoji' => '🇭🇰', 'unicode' => 'U+1F1ED U+1F1F0' },
    'HM' => { 'emoji' => '🇭🇲', 'unicode' => 'U+1F1ED U+1F1F2' },
    'HN' => { 'emoji' => '🇭🇳', 'unicode' => 'U+1F1ED U+1F1F3' },
    'HR' => { 'emoji' => '🇭🇷', 'unicode' => 'U+1F1ED U+1F1F7' },
    'HT' => { 'emoji' => '🇭🇹', 'unicode' => 'U+1F1ED U+1F1F9' },
    'HU' => { 'emoji' => '🇭🇺', 'unicode' => 'U+1F1ED U+1F1FA' },
    'ID' => { 'emoji' => '🇮🇩', 'unicode' => 'U+1F1EE U+1F1E9' },
    'IE' => { 'emoji' => '🇮🇪', 'unicode' => 'U+1F1EE U+1F1EA' },
    'IL' => { 'emoji' => '🇮🇱', 'unicode' => 'U+1F1EE U+1F1F1' },
    'IM' => { 'emoji' => '🇮🇲', 'unicode' => 'U+1F1EE U+1F1F2' },
    'IN' => { 'emoji' => '🇮🇳', 'unicode' => 'U+1F1EE U+1F1F3' },
    'IO' => { 'emoji' => '🇮🇴', 'unicode' => 'U+1F1EE U+1F1F4' },
    'IQ' => { 'emoji' => '🇮🇶', 'unicode' => 'U+1F1EE U+1F1F6' },
    'IR' => { 'emoji' => '🇮🇷', 'unicode' => 'U+1F1EE U+1F1F7' },
    'IS' => { 'emoji' => '🇮🇸', 'unicode' => 'U+1F1EE U+1F1F8' },
    'IT' => { 'emoji' => '🇮🇹', 'unicode' => 'U+1F1EE U+1F1F9' },
    'JE' => { 'emoji' => '🇯🇪', 'unicode' => 'U+1F1EF U+1F1EA' },
    'JM' => { 'emoji' => '🇯🇲', 'unicode' => 'U+1F1EF U+1F1F2' },
    'JO' => { 'emoji' => '🇯🇴', 'unicode' => 'U+1F1EF U+1F1F4' },
    'JP' => { 'emoji' => '🇯🇵', 'unicode' => 'U+1F1EF U+1F1F5' },
    'KE' => { 'emoji' => '🇰🇪', 'unicode' => 'U+1F1F0 U+1F1EA' },
    'KG' => { 'emoji' => '🇰🇬', 'unicode' => 'U+1F1F0 U+1F1EC' },
    'KH' => { 'emoji' => '🇰🇭', 'unicode' => 'U+1F1F0 U+1F1ED' },
    'KI' => { 'emoji' => '🇰🇮', 'unicode' => 'U+1F1F0 U+1F1EE' },
    'KM' => { 'emoji' => '🇰🇲', 'unicode' => 'U+1F1F0 U+1F1F2' },
    'KN' => { 'emoji' => '🇰🇳', 'unicode' => 'U+1F1F0 U+1F1F3' },
    'KP' => { 'emoji' => '🇰🇵', 'unicode' => 'U+1F1F0 U+1F1F5' },
    'KR' => { 'emoji' => '🇰🇷', 'unicode' => 'U+1F1F0 U+1F1F7' },
    'KW' => { 'emoji' => '🇰🇼', 'unicode' => 'U+1F1F0 U+1F1FC' },
    'KY' => { 'emoji' => '🇰🇾', 'unicode' => 'U+1F1F0 U+1F1FE' },
    'KZ' => { 'emoji' => '🇰🇿', 'unicode' => 'U+1F1F0 U+1F1FF' },
    'LA' => { 'emoji' => '🇱🇦', 'unicode' => 'U+1F1F1 U+1F1E6' },
    'LB' => { 'emoji' => '🇱🇧', 'unicode' => 'U+1F1F1 U+1F1E7' },
    'LC' => { 'emoji' => '🇱🇨', 'unicode' => 'U+1F1F1 U+1F1E8' },
    'LI' => { 'emoji' => '🇱🇮', 'unicode' => 'U+1F1F1 U+1F1EE' },
    'LK' => { 'emoji' => '🇱🇰', 'unicode' => 'U+1F1F1 U+1F1F0' },
    'LR' => { 'emoji' => '🇱🇷', 'unicode' => 'U+1F1F1 U+1F1F7' },
    'LS' => { 'emoji' => '🇱🇸', 'unicode' => 'U+1F1F1 U+1F1F8' },
    'LT' => { 'emoji' => '🇱🇹', 'unicode' => 'U+1F1F1 U+1F1F9' },
    'LU' => { 'emoji' => '🇱🇺', 'unicode' => 'U+1F1F1 U+1F1FA' },
    'LV' => { 'emoji' => '🇱🇻', 'unicode' => 'U+1F1F1 U+1F1FB' },
    'LY' => { 'emoji' => '🇱🇾', 'unicode' => 'U+1F1F1 U+1F1FE' },
    'MA' => { 'emoji' => '🇲🇦', 'unicode' => 'U+1F1F2 U+1F1E6' },
    'MC' => { 'emoji' => '🇲🇨', 'unicode' => 'U+1F1F2 U+1F1E8' },
    'MD' => { 'emoji' => '🇲🇩', 'unicode' => 'U+1F1F2 U+1F1E9' },
    'ME' => { 'emoji' => '🇲🇪', 'unicode' => 'U+1F1F2 U+1F1EA' },
    'MF' => { 'emoji' => '🇲🇫', 'unicode' => 'U+1F1F2 U+1F1EB' },
    'MG' => { 'emoji' => '🇲🇬', 'unicode' => 'U+1F1F2 U+1F1EC' },
    'MH' => { 'emoji' => '🇲🇭', 'unicode' => 'U+1F1F2 U+1F1ED' },
    'MK' => { 'emoji' => '🇲🇰', 'unicode' => 'U+1F1F2 U+1F1F0' },
    'ML' => { 'emoji' => '🇲🇱', 'unicode' => 'U+1F1F2 U+1F1F1' },
    'MM' => { 'emoji' => '🇲🇲', 'unicode' => 'U+1F1F2 U+1F1F2' },
    'MN' => { 'emoji' => '🇲🇳', 'unicode' => 'U+1F1F2 U+1F1F3' },
    'MO' => { 'emoji' => '🇲🇴', 'unicode' => 'U+1F1F2 U+1F1F4' },
    'MP' => { 'emoji' => '🇲🇵', 'unicode' => 'U+1F1F2 U+1F1F5' },
    'MQ' => { 'emoji' => '🇲🇶', 'unicode' => 'U+1F1F2 U+1F1F6' },
    'MR' => { 'emoji' => '🇲🇷', 'unicode' => 'U+1F1F2 U+1F1F7' },
    'MS' => { 'emoji' => '🇲🇸', 'unicode' => 'U+1F1F2 U+1F1F8' },
    'MT' => { 'emoji' => '🇲🇹', 'unicode' => 'U+1F1F2 U+1F1F9' },
    'MU' => { 'emoji' => '🇲🇺', 'unicode' => 'U+1F1F2 U+1F1FA' },
    'MV' => { 'emoji' => '🇲🇻', 'unicode' => 'U+1F1F2 U+1F1FB' },
    'MW' => { 'emoji' => '🇲🇼', 'unicode' => 'U+1F1F2 U+1F1FC' },
    'MX' => { 'emoji' => '🇲🇽', 'unicode' => 'U+1F1F2 U+1F1FD' },
    'MY' => { 'emoji' => '🇲🇾', 'unicode' => 'U+1F1F2 U+1F1FE' },
    'MZ' => { 'emoji' => '🇲🇿', 'unicode' => 'U+1F1F2 U+1F1FF' },
    'NA' => { 'emoji' => '🇳🇦', 'unicode' => 'U+1F1F3 U+1F1E6' },
    'NC' => { 'emoji' => '🇳🇨', 'unicode' => 'U+1F1F3 U+1F1E8' },
    'NE' => { 'emoji' => '🇳🇪', 'unicode' => 'U+1F1F3 U+1F1EA' },
    'NF' => { 'emoji' => '🇳🇫', 'unicode' => 'U+1F1F3 U+1F1EB' },
    'NG' => { 'emoji' => '🇳🇬', 'unicode' => 'U+1F1F3 U+1F1EC' },
    'NI' => { 'emoji' => '🇳🇮', 'unicode' => 'U+1F1F3 U+1F1EE' },
    'NL' => { 'emoji' => '🇳🇱', 'unicode' => 'U+1F1F3 U+1F1F1' },
    'NO' => { 'emoji' => '🇳🇴', 'unicode' => 'U+1F1F3 U+1F1F4' },
    'NP' => { 'emoji' => '🇳🇵', 'unicode' => 'U+1F1F3 U+1F1F5' },
    'NR' => { 'emoji' => '🇳🇷', 'unicode' => 'U+1F1F3 U+1F1F7' },
    'NU' => { 'emoji' => '🇳🇺', 'unicode' => 'U+1F1F3 U+1F1FA' },
    'NZ' => { 'emoji' => '🇳🇿', 'unicode' => 'U+1F1F3 U+1F1FF' },
    'OM' => { 'emoji' => '🇴🇲', 'unicode' => 'U+1F1F4 U+1F1F2' },
    'PA' => { 'emoji' => '🇵🇦', 'unicode' => 'U+1F1F5 U+1F1E6' },
    'PE' => { 'emoji' => '🇵🇪', 'unicode' => 'U+1F1F5 U+1F1EA' },
    'PF' => { 'emoji' => '🇵🇫', 'unicode' => 'U+1F1F5 U+1F1EB' },
    'PG' => { 'emoji' => '🇵🇬', 'unicode' => 'U+1F1F5 U+1F1EC' },
    'PH' => { 'emoji' => '🇵🇭', 'unicode' => 'U+1F1F5 U+1F1ED' },
    'PK' => { 'emoji' => '🇵🇰', 'unicode' => 'U+1F1F5 U+1F1F0' },
    'PL' => { 'emoji' => '🇵🇱', 'unicode' => 'U+1F1F5 U+1F1F1' },
    'PM' => { 'emoji' => '🇵🇲', 'unicode' => 'U+1F1F5 U+1F1F2' },
    'PN' => { 'emoji' => '🇵🇳', 'unicode' => 'U+1F1F5 U+1F1F3' },
    'PR' => { 'emoji' => '🇵🇷', 'unicode' => 'U+1F1F5 U+1F1F7' },
    'PS' => { 'emoji' => '🇵🇸', 'unicode' => 'U+1F1F5 U+1F1F8' },
    'PT' => { 'emoji' => '🇵🇹', 'unicode' => 'U+1F1F5 U+1F1F9' },
    'PW' => { 'emoji' => '🇵🇼', 'unicode' => 'U+1F1F5 U+1F1FC' },
    'PY' => { 'emoji' => '🇵🇾', 'unicode' => 'U+1F1F5 U+1F1FE' },
    'QA' => { 'emoji' => '🇶🇦', 'unicode' => 'U+1F1F6 U+1F1E6' },
    'RE' => { 'emoji' => '🇷🇪', 'unicode' => 'U+1F1F7 U+1F1EA' },
    'RO' => { 'emoji' => '🇷🇴', 'unicode' => 'U+1F1F7 U+1F1F4' },
    'RS' => { 'emoji' => '🇷🇸', 'unicode' => 'U+1F1F7 U+1F1F8' },
    'RU' => { 'emoji' => '🇷🇺', 'unicode' => 'U+1F1F7 U+1F1FA' },
    'RW' => { 'emoji' => '🇷🇼', 'unicode' => 'U+1F1F7 U+1F1FC' },
    'SA' => { 'emoji' => '🇸🇦', 'unicode' => 'U+1F1F8 U+1F1E6' },
    'SB' => { 'emoji' => '🇸🇧', 'unicode' => 'U+1F1F8 U+1F1E7' },
    'SC' => { 'emoji' => '🇸🇨', 'unicode' => 'U+1F1F8 U+1F1E8' },
    'SD' => { 'emoji' => '🇸🇩', 'unicode' => 'U+1F1F8 U+1F1E9' },
    'SE' => { 'emoji' => '🇸🇪', 'unicode' => 'U+1F1F8 U+1F1EA' },
    'SG' => { 'emoji' => '🇸🇬', 'unicode' => 'U+1F1F8 U+1F1EC' },
    'SH' => { 'emoji' => '🇸🇭', 'unicode' => 'U+1F1F8 U+1F1ED' },
    'SI' => { 'emoji' => '🇸🇮', 'unicode' => 'U+1F1F8 U+1F1EE' },
    'SJ' => { 'emoji' => '🇸🇯', 'unicode' => 'U+1F1F8 U+1F1EF' },
    'SK' => { 'emoji' => '🇸🇰', 'unicode' => 'U+1F1F8 U+1F1F0' },
    'SL' => { 'emoji' => '🇸🇱', 'unicode' => 'U+1F1F8 U+1F1F1' },
    'SM' => { 'emoji' => '🇸🇲', 'unicode' => 'U+1F1F8 U+1F1F2' },
    'SN' => { 'emoji' => '🇸🇳', 'unicode' => 'U+1F1F8 U+1F1F3' },
    'SO' => { 'emoji' => '🇸🇴', 'unicode' => 'U+1F1F8 U+1F1F4' },
    'SR' => { 'emoji' => '🇸🇷', 'unicode' => 'U+1F1F8 U+1F1F7' },
    'SS' => { 'emoji' => '🇸🇸', 'unicode' => 'U+1F1F8 U+1F1F8' },
    'ST' => { 'emoji' => '🇸🇹', 'unicode' => 'U+1F1F8 U+1F1F9' },
    'SV' => { 'emoji' => '🇸🇻', 'unicode' => 'U+1F1F8 U+1F1FB' },
    'SX' => { 'emoji' => '🇸🇽', 'unicode' => 'U+1F1F8 U+1F1FD' },
    'SY' => { 'emoji' => '🇸🇾', 'unicode' => 'U+1F1F8 U+1F1FE' },
    'SZ' => { 'emoji' => '🇸🇿', 'unicode' => 'U+1F1F8 U+1F1FF' },
    'TC' => { 'emoji' => '🇹🇨', 'unicode' => 'U+1F1F9 U+1F1E8' },
    'TD' => { 'emoji' => '🇹🇩', 'unicode' => 'U+1F1F9 U+1F1E9' },
    'TF' => { 'emoji' => '🇹🇫', 'unicode' => 'U+1F1F9 U+1F1EB' },
    'TG' => { 'emoji' => '🇹🇬', 'unicode' => 'U+1F1F9 U+1F1EC' },
    'TH' => { 'emoji' => '🇹🇭', 'unicode' => 'U+1F1F9 U+1F1ED' },
    'TJ' => { 'emoji' => '🇹🇯', 'unicode' => 'U+1F1F9 U+1F1EF' },
    'TK' => { 'emoji' => '🇹🇰', 'unicode' => 'U+1F1F9 U+1F1F0' },
    'TL' => { 'emoji' => '🇹🇱', 'unicode' => 'U+1F1F9 U+1F1F1' },
    'TM' => { 'emoji' => '🇹🇲', 'unicode' => 'U+1F1F9 U+1F1F2' },
    'TN' => { 'emoji' => '🇹🇳', 'unicode' => 'U+1F1F9 U+1F1F3' },
    'TO' => { 'emoji' => '🇹🇴', 'unicode' => 'U+1F1F9 U+1F1F4' },
    'TR' => { 'emoji' => '🇹🇷', 'unicode' => 'U+1F1F9 U+1F1F7' },
    'TT' => { 'emoji' => '🇹🇹', 'unicode' => 'U+1F1F9 U+1F1F9' },
    'TV' => { 'emoji' => '🇹🇻', 'unicode' => 'U+1F1F9 U+1F1FB' },
    'TW' => { 'emoji' => '🇹🇼', 'unicode' => 'U+1F1F9 U+1F1FC' },
    'TZ' => { 'emoji' => '🇹🇿', 'unicode' => 'U+1F1F9 U+1F1FF' },
    'UA' => { 'emoji' => '🇺🇦', 'unicode' => 'U+1F1FA U+1F1E6' },
    'UG' => { 'emoji' => '🇺🇬', 'unicode' => 'U+1F1FA U+1F1EC' },
    'UM' => { 'emoji' => '🇺🇲', 'unicode' => 'U+1F1FA U+1F1F2' },
    'US' => { 'emoji' => '🇺🇸', 'unicode' => 'U+1F1FA U+1F1F8' },
    'UY' => { 'emoji' => '🇺🇾', 'unicode' => 'U+1F1FA U+1F1FE' },
    'UZ' => { 'emoji' => '🇺🇿', 'unicode' => 'U+1F1FA U+1F1FF' },
    'VA' => { 'emoji' => '🇻🇦', 'unicode' => 'U+1F1FB U+1F1E6' },
    'VC' => { 'emoji' => '🇻🇨', 'unicode' => 'U+1F1FB U+1F1E8' },
    'VE' => { 'emoji' => '🇻🇪', 'unicode' => 'U+1F1FB U+1F1EA' },
    'VG' => { 'emoji' => '🇻🇬', 'unicode' => 'U+1F1FB U+1F1EC' },
    'VI' => { 'emoji' => '🇻🇮', 'unicode' => 'U+1F1FB U+1F1EE' },
    'VN' => { 'emoji' => '🇻🇳', 'unicode' => 'U+1F1FB U+1F1F3' },
    'VU' => { 'emoji' => '🇻🇺', 'unicode' => 'U+1F1FB U+1F1FA' },
    'WF' => { 'emoji' => '🇼🇫', 'unicode' => 'U+1F1FC U+1F1EB' },
    'WS' => { 'emoji' => '🇼🇸', 'unicode' => 'U+1F1FC U+1F1F8' },
    'XK' => { 'emoji' => '🇽🇰', 'unicode' => 'U+1F1FD U+1F1F0' },
    'YE' => { 'emoji' => '🇾🇪', 'unicode' => 'U+1F1FE U+1F1EA' },
    'YT' => { 'emoji' => '🇾🇹', 'unicode' => 'U+1F1FE U+1F1F9' },
    'ZA' => { 'emoji' => '🇿🇦', 'unicode' => 'U+1F1FF U+1F1E6' },
    'ZM' => { 'emoji' => '🇿🇲', 'unicode' => 'U+1F1FF U+1F1F2' },
    'ZW' => { 'emoji' => '🇿🇼', 'unicode' => 'U+1F1FF U+1F1FC' }
);
my @default_eu_countries = (
    "IE", "AT", "LT", "LU", "LV", "DE", "DK", "SE", "SI", "SK",
    "CZ", "CY", "NL", "FI", "FR", "MT", "ES", "IT", "EE", "PL",
    "PT", "HU", "HR", "GR", "RO", "BG", "BE"
);
my %default_countries_currencies = (
    'AD' => { 'code' => 'EUR', 'symbol' => '€' },
    'AE' => { 'code' => 'AED', 'symbol' => 'د.إ' },
    'AF' => { 'code' => 'AFN', 'symbol' => '؋' },
    'AG' => { 'code' => 'XCD', 'symbol' => '$' },
    'AI' => { 'code' => 'XCD', 'symbol' => '$' },
    'AL' => { 'code' => 'ALL', 'symbol' => 'L' },
    'AM' => { 'code' => 'AMD', 'symbol' => '֏' },
    'AO' => { 'code' => 'AOA', 'symbol' => 'Kz' },
    'AQ' => { 'code' => '',    'symbol' => '$' },
    'AR' => { 'code' => 'ARS', 'symbol' => '$' },
    'AS' => { 'code' => 'USD', 'symbol' => '$' },
    'AT' => { 'code' => 'EUR', 'symbol' => '€' },
    'AU' => { 'code' => 'AUD', 'symbol' => '$' },
    'AW' => { 'code' => 'AWG', 'symbol' => 'ƒ' },
    'AX' => { 'code' => 'EUR', 'symbol' => '€' },
    'AZ' => { 'code' => 'AZN', 'symbol' => '₼' },
    'BA' => { 'code' => 'BAM', 'symbol' => 'KM' },
    'BB' => { 'code' => 'BBD', 'symbol' => '$' },
    'BD' => { 'code' => 'BDT', 'symbol' => '৳' },
    'BE' => { 'code' => 'EUR', 'symbol' => '€' },
    'BF' => { 'code' => 'XOF', 'symbol' => 'CFA' },
    'BG' => { 'code' => 'BGN', 'symbol' => 'лв' },
    'BH' => { 'code' => 'BHD', 'symbol' => '.د.ب' },
    'BI' => { 'code' => 'BIF', 'symbol' => 'FBu' },
    'BJ' => { 'code' => 'XOF', 'symbol' => 'CFA' },
    'BL' => { 'code' => 'EUR', 'symbol' => '€' },
    'BM' => { 'code' => 'BMD', 'symbol' => '$' },
    'BN' => { 'code' => 'BND', 'symbol' => '$' },
    'BO' => { 'code' => 'BOB', 'symbol' => '$b' },
    'BQ' => { 'code' => 'USD', 'symbol' => '$' },
    'BR' => { 'code' => 'BRL', 'symbol' => 'R$' },
    'BS' => { 'code' => 'BSD', 'symbol' => '$' },
    'BT' => { 'code' => 'BTN', 'symbol' => 'Nu.' },
    'BV' => { 'code' => 'NOK', 'symbol' => 'kr' },
    'BW' => { 'code' => 'BWP', 'symbol' => 'P' },
    'BY' => { 'code' => 'BYR', 'symbol' => 'Br' },
    'BZ' => { 'code' => 'BZD', 'symbol' => 'BZ$' },
    'CA' => { 'code' => 'CAD', 'symbol' => '$' },
    'CC' => { 'code' => 'AUD', 'symbol' => '$' },
    'CD' => { 'code' => 'CDF', 'symbol' => 'FC' },
    'CF' => { 'code' => 'XAF', 'symbol' => 'FCFA' },
    'CG' => { 'code' => 'XAF', 'symbol' => 'FCFA' },
    'CH' => { 'code' => 'CHF', 'symbol' => 'CHF' },
    'CI' => { 'code' => 'XOF', 'symbol' => 'CFA' },
    'CK' => { 'code' => 'NZD', 'symbol' => '$' },
    'CL' => { 'code' => 'CLP', 'symbol' => '$' },
    'CM' => { 'code' => 'XAF', 'symbol' => 'FCFA' },
    'CN' => { 'code' => 'CNY', 'symbol' => '¥' },
    'CO' => { 'code' => 'COP', 'symbol' => '$' },
    'CR' => { 'code' => 'CRC', 'symbol' => '₡' },
    'CU' => { 'code' => 'CUP', 'symbol' => '₱' },
    'CV' => { 'code' => 'CVE', 'symbol' => '$' },
    'CW' => { 'code' => 'ANG', 'symbol' => 'ƒ' },
    'CX' => { 'code' => 'AUD', 'symbol' => '$' },
    'CY' => { 'code' => 'EUR', 'symbol' => '€' },
    'CZ' => { 'code' => 'CZK', 'symbol' => 'Kč' },
    'DE' => { 'code' => 'EUR', 'symbol' => '€' },
    'DJ' => { 'code' => 'DJF', 'symbol' => 'Fdj' },
    'DK' => { 'code' => 'DKK', 'symbol' => 'kr' },
    'DM' => { 'code' => 'XCD', 'symbol' => '$' },
    'DO' => { 'code' => 'DOP', 'symbol' => 'RD$' },
    'DZ' => { 'code' => 'DZD', 'symbol' => 'دج' },
    'EC' => { 'code' => 'USD', 'symbol' => '$' },
    'EE' => { 'code' => 'EUR', 'symbol' => '€' },
    'EG' => { 'code' => 'EGP', 'symbol' => '£' },
    'EH' => { 'code' => 'MAD', 'symbol' => 'MAD' },
    'ER' => { 'code' => 'ERN', 'symbol' => 'Nfk' },
    'ES' => { 'code' => 'EUR', 'symbol' => '€' },
    'ET' => { 'code' => 'ETB', 'symbol' => 'Br' },
    'FI' => { 'code' => 'EUR', 'symbol' => '€' },
    'FJ' => { 'code' => 'FJD', 'symbol' => '$' },
    'FK' => { 'code' => 'FKP', 'symbol' => '£' },
    'FM' => { 'code' => 'USD', 'symbol' => '$' },
    'FO' => { 'code' => 'DKK', 'symbol' => 'kr' },
    'FR' => { 'code' => 'EUR', 'symbol' => '€' },
    'GA' => { 'code' => 'XAF', 'symbol' => 'FCFA' },
    'GB' => { 'code' => 'GBP', 'symbol' => '£' },
    'GD' => { 'code' => 'XCD', 'symbol' => '$' },
    'GE' => { 'code' => 'GEL', 'symbol' => 'ლ' },
    'GF' => { 'code' => 'EUR', 'symbol' => '€' },
    'GG' => { 'code' => 'GBP', 'symbol' => '£' },
    'GH' => { 'code' => 'GHS', 'symbol' => 'GH₵' },
    'GI' => { 'code' => 'GIP', 'symbol' => '£' },
    'GL' => { 'code' => 'DKK', 'symbol' => 'kr' },
    'GM' => { 'code' => 'GMD', 'symbol' => 'D' },
    'GN' => { 'code' => 'GNF', 'symbol' => 'FG' },
    'GP' => { 'code' => 'EUR', 'symbol' => '€' },
    'GQ' => { 'code' => 'XAF', 'symbol' => 'FCFA' },
    'GR' => { 'code' => 'EUR', 'symbol' => '€' },
    'GS' => { 'code' => 'GBP', 'symbol' => '£' },
    'GT' => { 'code' => 'GTQ', 'symbol' => 'Q' },
    'GU' => { 'code' => 'USD', 'symbol' => '$' },
    'GW' => { 'code' => 'XOF', 'symbol' => 'CFA' },
    'GY' => { 'code' => 'GYD', 'symbol' => '$' },
    'HK' => { 'code' => 'HKD', 'symbol' => '$' },
    'HM' => { 'code' => 'AUD', 'symbol' => '$' },
    'HN' => { 'code' => 'HNL', 'symbol' => 'L' },
    'HR' => { 'code' => 'HRK', 'symbol' => 'kn' },
    'HT' => { 'code' => 'HTG', 'symbol' => 'G' },
    'HU' => { 'code' => 'HUF', 'symbol' => 'Ft' },
    'ID' => { 'code' => 'IDR', 'symbol' => 'Rp' },
    'IE' => { 'code' => 'EUR', 'symbol' => '€' },
    'IL' => { 'code' => 'ILS', 'symbol' => '₪' },
    'IM' => { 'code' => 'GBP', 'symbol' => '£' },
    'IN' => { 'code' => 'INR', 'symbol' => '₹' },
    'IO' => { 'code' => 'USD', 'symbol' => '$' },
    'IQ' => { 'code' => 'IQD', 'symbol' => 'ع.د' },
    'IR' => { 'code' => 'IRR', 'symbol' => '﷼' },
    'IS' => { 'code' => 'ISK', 'symbol' => 'kr' },
    'IT' => { 'code' => 'EUR', 'symbol' => '€' },
    'JE' => { 'code' => 'GBP', 'symbol' => '£' },
    'JM' => { 'code' => 'JMD', 'symbol' => 'J$' },
    'JO' => { 'code' => 'JOD', 'symbol' => 'JD' },
    'JP' => { 'code' => 'JPY', 'symbol' => '¥' },
    'KE' => { 'code' => 'KES', 'symbol' => 'KSh' },
    'KG' => { 'code' => 'KGS', 'symbol' => 'лв' },
    'KH' => { 'code' => 'KHR', 'symbol' => '៛' },
    'KI' => { 'code' => 'AUD', 'symbol' => '$' },
    'KM' => { 'code' => 'KMF', 'symbol' => 'CF' },
    'KN' => { 'code' => 'XCD', 'symbol' => '$' },
    'KP' => { 'code' => 'KPW', 'symbol' => '₩' },
    'KR' => { 'code' => 'KRW', 'symbol' => '₩' },
    'KW' => { 'code' => 'KWD', 'symbol' => 'KD' },
    'KY' => { 'code' => 'KYD', 'symbol' => '$' },
    'KZ' => { 'code' => 'KZT', 'symbol' => '₸' },
    'LA' => { 'code' => 'LAK', 'symbol' => '₭' },
    'LB' => { 'code' => 'LBP', 'symbol' => '£' },
    'LC' => { 'code' => 'XCD', 'symbol' => '$' },
    'LI' => { 'code' => 'CHF', 'symbol' => 'CHF' },
    'LK' => { 'code' => 'LKR', 'symbol' => '₨' },
    'LR' => { 'code' => 'LRD', 'symbol' => '$' },
    'LS' => { 'code' => 'LSL', 'symbol' => 'M' },
    'LT' => { 'code' => 'LTL', 'symbol' => 'Lt' },
    'LU' => { 'code' => 'EUR', 'symbol' => '€' },
    'LV' => { 'code' => 'EUR', 'symbol' => '€' },
    'LY' => { 'code' => 'LYD', 'symbol' => 'LD' },
    'MA' => { 'code' => 'MAD', 'symbol' => 'MAD' },
    'MC' => { 'code' => 'EUR', 'symbol' => '€' },
    'MD' => { 'code' => 'MDL', 'symbol' => 'lei' },
    'ME' => { 'code' => 'EUR', 'symbol' => '€' },
    'MF' => { 'code' => 'EUR', 'symbol' => '€' },
    'MG' => { 'code' => 'MGA', 'symbol' => 'Ar' },
    'MH' => { 'code' => 'USD', 'symbol' => '$' },
    'MK' => { 'code' => 'MKD', 'symbol' => 'ден' },
    'ML' => { 'code' => 'XOF', 'symbol' => 'CFA' },
    'MM' => { 'code' => 'MMK', 'symbol' => 'K' },
    'MN' => { 'code' => 'MNT', 'symbol' => '₮' },
    'MO' => { 'code' => 'MOP', 'symbol' => 'MOP$' },
    'MP' => { 'code' => 'USD', 'symbol' => '$' },
    'MQ' => { 'code' => 'EUR', 'symbol' => '€' },
    'MR' => { 'code' => 'MRO', 'symbol' => 'UM' },
    'MS' => { 'code' => 'XCD', 'symbol' => '$' },
    'MT' => { 'code' => 'EUR', 'symbol' => '€' },
    'MU' => { 'code' => 'MUR', 'symbol' => '₨' },
    'MV' => { 'code' => 'MVR', 'symbol' => 'Rf' },
    'MW' => { 'code' => 'MWK', 'symbol' => 'MK' },
    'MX' => { 'code' => 'MXN', 'symbol' => '$' },
    'MY' => { 'code' => 'MYR', 'symbol' => 'RM' },
    'MZ' => { 'code' => 'MZN', 'symbol' => 'MT' },
    'NA' => { 'code' => 'NAD', 'symbol' => '$' },
    'NC' => { 'code' => 'XPF', 'symbol' => '₣' },
    'NE' => { 'code' => 'XOF', 'symbol' => 'CFA' },
    'NF' => { 'code' => 'AUD', 'symbol' => '$' },
    'NG' => { 'code' => 'NGN', 'symbol' => '₦' },
    'NI' => { 'code' => 'NIO', 'symbol' => 'C$' },
    'NL' => { 'code' => 'EUR', 'symbol' => '€' },
    'NO' => { 'code' => 'NOK', 'symbol' => 'kr' },
    'NP' => { 'code' => 'NPR', 'symbol' => '₨' },
    'NR' => { 'code' => 'AUD', 'symbol' => '$' },
    'NU' => { 'code' => 'NZD', 'symbol' => '$' },
    'NZ' => { 'code' => 'NZD', 'symbol' => '$' },
    'OM' => { 'code' => 'OMR', 'symbol' => '﷼' },
    'PA' => { 'code' => 'PAB', 'symbol' => 'B/.' },
    'PE' => { 'code' => 'PEN', 'symbol' => 'S/.' },
    'PF' => { 'code' => 'XPF', 'symbol' => '₣' },
    'PG' => { 'code' => 'PGK', 'symbol' => 'K' },
    'PH' => { 'code' => 'PHP', 'symbol' => '₱' },
    'PK' => { 'code' => 'PKR', 'symbol' => '₨' },
    'PL' => { 'code' => 'PLN', 'symbol' => 'zł' },
    'PM' => { 'code' => 'EUR', 'symbol' => '€' },
    'PN' => { 'code' => 'NZD', 'symbol' => '$' },
    'PR' => { 'code' => 'USD', 'symbol' => '$' },
    'PS' => { 'code' => 'ILS', 'symbol' => '₪' },
    'PT' => { 'code' => 'EUR', 'symbol' => '€' },
    'PW' => { 'code' => 'USD', 'symbol' => '$' },
    'PY' => { 'code' => 'PYG', 'symbol' => 'Gs' },
    'QA' => { 'code' => 'QAR', 'symbol' => '﷼' },
    'RE' => { 'code' => 'EUR', 'symbol' => '€' },
    'RO' => { 'code' => 'RON', 'symbol' => 'lei' },
    'RS' => { 'code' => 'RSD', 'symbol' => 'Дин.' },
    'RU' => { 'code' => 'RUB', 'symbol' => '₽' },
    'RW' => { 'code' => 'RWF', 'symbol' => 'R₣' },
    'SA' => { 'code' => 'SAR', 'symbol' => '﷼' },
    'SB' => { 'code' => 'SBD', 'symbol' => '$' },
    'SC' => { 'code' => 'SCR', 'symbol' => '₨' },
    'SD' => { 'code' => 'SDG', 'symbol' => 'ج.س.' },
    'SE' => { 'code' => 'SEK', 'symbol' => 'kr' },
    'SG' => { 'code' => 'SGD', 'symbol' => 'S$' },
    'SH' => { 'code' => 'SHP', 'symbol' => '£' },
    'SI' => { 'code' => 'EUR', 'symbol' => '€' },
    'SJ' => { 'code' => 'NOK', 'symbol' => 'kr' },
    'SK' => { 'code' => 'EUR', 'symbol' => '€' },
    'SL' => { 'code' => 'SLL', 'symbol' => 'Le' },
    'SM' => { 'code' => 'EUR', 'symbol' => '€' },
    'SN' => { 'code' => 'XOF', 'symbol' => 'CFA' },
    'SO' => { 'code' => 'SOS', 'symbol' => 'S' },
    'SR' => { 'code' => 'SRD', 'symbol' => '$' },
    'SS' => { 'code' => 'SSP', 'symbol' => '£' },
    'ST' => { 'code' => 'STD', 'symbol' => 'Db' },
    'SV' => { 'code' => 'USD', 'symbol' => '$' },
    'SX' => { 'code' => 'ANG', 'symbol' => 'ƒ' },
    'SY' => { 'code' => 'SYP', 'symbol' => '£' },
    'SZ' => { 'code' => 'SZL', 'symbol' => 'E' },
    'TC' => { 'code' => 'USD', 'symbol' => '$' },
    'TD' => { 'code' => 'XAF', 'symbol' => 'FCFA' },
    'TF' => { 'code' => 'EUR', 'symbol' => '€' },
    'TG' => { 'code' => 'XOF', 'symbol' => 'CFA' },
    'TH' => { 'code' => 'THB', 'symbol' => '฿' },
    'TJ' => { 'code' => 'TJS', 'symbol' => 'SM' },
    'TK' => { 'code' => 'NZD', 'symbol' => '$' },
    'TL' => { 'code' => 'USD', 'symbol' => '$' },
    'TM' => { 'code' => 'TMT', 'symbol' => 'T' },
    'TN' => { 'code' => 'TND', 'symbol' => 'د.ت' },
    'TO' => { 'code' => 'TOP', 'symbol' => 'T$' },
    'TR' => { 'code' => 'TRY', 'symbol' => '₺' },
    'TT' => { 'code' => 'TTD', 'symbol' => 'TT$' },
    'TV' => { 'code' => 'AUD', 'symbol' => '$' },
    'TW' => { 'code' => 'TWD', 'symbol' => 'NT$' },
    'TZ' => { 'code' => 'TZS', 'symbol' => 'TSh' },
    'UA' => { 'code' => 'UAH', 'symbol' => '₴' },
    'UG' => { 'code' => 'UGX', 'symbol' => 'USh' },
    'UM' => { 'code' => 'USD', 'symbol' => '$' },
    'US' => { 'code' => 'USD', 'symbol' => '$' },
    'UY' => { 'code' => 'UYU', 'symbol' => '$U' },
    'UZ' => { 'code' => 'UZS', 'symbol' => 'лв' },
    'VA' => { 'code' => 'EUR', 'symbol' => '€' },
    'VC' => { 'code' => 'XCD', 'symbol' => '$' },
    'VE' => { 'code' => 'VEF', 'symbol' => 'Bs' },
    'VG' => { 'code' => 'USD', 'symbol' => '$' },
    'VI' => { 'code' => 'USD', 'symbol' => '$' },
    'VN' => { 'code' => 'VND', 'symbol' => '₫' },
    'VU' => { 'code' => 'VUV', 'symbol' => 'VT' },
    'WF' => { 'code' => 'XPF', 'symbol' => '₣' },
    'WS' => { 'code' => 'WST', 'symbol' => 'WS$' },
    'XK' => { 'code' => 'EUR', 'symbol' => '€' },
    'YE' => { 'code' => 'YER', 'symbol' => '﷼' },
    'YT' => { 'code' => 'EUR', 'symbol' => '€' },
    'ZA' => { 'code' => 'ZAR', 'symbol' => 'R' },
    'ZM' => { 'code' => 'ZMK', 'symbol' => 'ZK' },
    'ZW' => { 'code' => 'ZWL', 'symbol' => '$' }
);
my %default_continents = (
    "BD" => { "code" => "AS", "name" => "Asia" },
    "BE" => { "code" => "EU", "name" => "Europe" },
    "BF" => { "code" => "AF", "name" => "Africa" },
    "BG" => { "code" => "EU", "name" => "Europe" },
    "BA" => { "code" => "EU", "name" => "Europe" },
    "BB" => { "code" => "NA", "name" => "North America" },
    "WF" => { "code" => "OC", "name" => "Oceania" },
    "BL" => { "code" => "NA", "name" => "North America" },
    "BM" => { "code" => "NA", "name" => "North America" },
    "BN" => { "code" => "AS", "name" => "Asia" },
    "BO" => { "code" => "SA", "name" => "South America" },
    "BH" => { "code" => "AS", "name" => "Asia" },
    "BI" => { "code" => "AF", "name" => "Africa" },
    "BJ" => { "code" => "AF", "name" => "Africa" },
    "BT" => { "code" => "AS", "name" => "Asia" },
    "JM" => { "code" => "NA", "name" => "North America" },
    "BV" => { "code" => "AN", "name" => "Antarctica" },
    "BW" => { "code" => "AF", "name" => "Africa" },
    "WS" => { "code" => "OC", "name" => "Oceania" },
    "BQ" => { "code" => "NA", "name" => "North America" },
    "BR" => { "code" => "SA", "name" => "South America" },
    "BS" => { "code" => "NA", "name" => "North America" },
    "JE" => { "code" => "EU", "name" => "Europe" },
    "BY" => { "code" => "EU", "name" => "Europe" },
    "BZ" => { "code" => "NA", "name" => "North America" },
    "RU" => { "code" => "EU", "name" => "Europe" },
    "RW" => { "code" => "AF", "name" => "Africa" },
    "RS" => { "code" => "EU", "name" => "Europe" },
    "TL" => { "code" => "OC", "name" => "Oceania" },
    "RE" => { "code" => "AF", "name" => "Africa" },
    "TM" => { "code" => "AS", "name" => "Asia" },
    "TJ" => { "code" => "AS", "name" => "Asia" },
    "RO" => { "code" => "EU", "name" => "Europe" },
    "TK" => { "code" => "OC", "name" => "Oceania" },
    "GW" => { "code" => "AF", "name" => "Africa" },
    "GU" => { "code" => "OC", "name" => "Oceania" },
    "GT" => { "code" => "NA", "name" => "North America" },
    "GS" => { "code" => "AN", "name" => "Antarctica" },
    "GR" => { "code" => "EU", "name" => "Europe" },
    "GQ" => { "code" => "AF", "name" => "Africa" },
    "GP" => { "code" => "NA", "name" => "North America" },
    "JP" => { "code" => "AS", "name" => "Asia" },
    "GY" => { "code" => "SA", "name" => "South America" },
    "GG" => { "code" => "EU", "name" => "Europe" },
    "GF" => { "code" => "SA", "name" => "South America" },
    "GE" => { "code" => "AS", "name" => "Asia" },
    "GD" => { "code" => "NA", "name" => "North America" },
    "GB" => { "code" => "EU", "name" => "Europe" },
    "GA" => { "code" => "AF", "name" => "Africa" },
    "SV" => { "code" => "NA", "name" => "North America" },
    "GN" => { "code" => "AF", "name" => "Africa" },
    "GM" => { "code" => "AF", "name" => "Africa" },
    "GL" => { "code" => "NA", "name" => "North America" },
    "GI" => { "code" => "EU", "name" => "Europe" },
    "GH" => { "code" => "AF", "name" => "Africa" },
    "OM" => { "code" => "AS", "name" => "Asia" },
    "TN" => { "code" => "AF", "name" => "Africa" },
    "JO" => { "code" => "AS", "name" => "Asia" },
    "HR" => { "code" => "EU", "name" => "Europe" },
    "HT" => { "code" => "NA", "name" => "North America" },
    "HU" => { "code" => "EU", "name" => "Europe" },
    "HK" => { "code" => "AS", "name" => "Asia" },
    "HN" => { "code" => "NA", "name" => "North America" },
    "HM" => { "code" => "AN", "name" => "Antarctica" },
    "VE" => { "code" => "SA", "name" => "South America" },
    "PR" => { "code" => "NA", "name" => "North America" },
    "PS" => { "code" => "AS", "name" => "Asia" },
    "PW" => { "code" => "OC", "name" => "Oceania" },
    "PT" => { "code" => "EU", "name" => "Europe" },
    "SJ" => { "code" => "EU", "name" => "Europe" },
    "PY" => { "code" => "SA", "name" => "South America" },
    "IQ" => { "code" => "AS", "name" => "Asia" },
    "PA" => { "code" => "NA", "name" => "North America" },
    "PF" => { "code" => "OC", "name" => "Oceania" },
    "PG" => { "code" => "OC", "name" => "Oceania" },
    "PE" => { "code" => "SA", "name" => "South America" },
    "PK" => { "code" => "AS", "name" => "Asia" },
    "PH" => { "code" => "AS", "name" => "Asia" },
    "PN" => { "code" => "OC", "name" => "Oceania" },
    "PL" => { "code" => "EU", "name" => "Europe" },
    "PM" => { "code" => "NA", "name" => "North America" },
    "ZM" => { "code" => "AF", "name" => "Africa" },
    "EH" => { "code" => "AF", "name" => "Africa" },
    "EE" => { "code" => "EU", "name" => "Europe" },
    "EG" => { "code" => "AF", "name" => "Africa" },
    "ZA" => { "code" => "AF", "name" => "Africa" },
    "EC" => { "code" => "SA", "name" => "South America" },
    "IT" => { "code" => "EU", "name" => "Europe" },
    "VN" => { "code" => "AS", "name" => "Asia" },
    "SB" => { "code" => "OC", "name" => "Oceania" },
    "ET" => { "code" => "AF", "name" => "Africa" },
    "SO" => { "code" => "AF", "name" => "Africa" },
    "ZW" => { "code" => "AF", "name" => "Africa" },
    "SA" => { "code" => "AS", "name" => "Asia" },
    "ES" => { "code" => "EU", "name" => "Europe" },
    "ER" => { "code" => "AF", "name" => "Africa" },
    "ME" => { "code" => "EU", "name" => "Europe" },
    "MD" => { "code" => "EU", "name" => "Europe" },
    "MG" => { "code" => "AF", "name" => "Africa" },
    "MF" => { "code" => "NA", "name" => "North America" },
    "MA" => { "code" => "AF", "name" => "Africa" },
    "MC" => { "code" => "EU", "name" => "Europe" },
    "UZ" => { "code" => "AS", "name" => "Asia" },
    "MM" => { "code" => "AS", "name" => "Asia" },
    "ML" => { "code" => "AF", "name" => "Africa" },
    "MO" => { "code" => "AS", "name" => "Asia" },
    "MN" => { "code" => "AS", "name" => "Asia" },
    "MH" => { "code" => "OC", "name" => "Oceania" },
    "MK" => { "code" => "EU", "name" => "Europe" },
    "MU" => { "code" => "AF", "name" => "Africa" },
    "MT" => { "code" => "EU", "name" => "Europe" },
    "MW" => { "code" => "AF", "name" => "Africa" },
    "MV" => { "code" => "AS", "name" => "Asia" },
    "MQ" => { "code" => "NA", "name" => "North America" },
    "MP" => { "code" => "OC", "name" => "Oceania" },
    "MS" => { "code" => "NA", "name" => "North America" },
    "MR" => { "code" => "AF", "name" => "Africa" },
    "IM" => { "code" => "EU", "name" => "Europe" },
    "UG" => { "code" => "AF", "name" => "Africa" },
    "TZ" => { "code" => "AF", "name" => "Africa" },
    "MY" => { "code" => "AS", "name" => "Asia" },
    "MX" => { "code" => "NA", "name" => "North America" },
    "IL" => { "code" => "AS", "name" => "Asia" },
    "FR" => { "code" => "EU", "name" => "Europe" },
    "IO" => { "code" => "AS", "name" => "Asia" },
    "SH" => { "code" => "AF", "name" => "Africa" },
    "FI" => { "code" => "EU", "name" => "Europe" },
    "FJ" => { "code" => "OC", "name" => "Oceania" },
    "FK" => { "code" => "SA", "name" => "South America" },
    "FM" => { "code" => "OC", "name" => "Oceania" },
    "FO" => { "code" => "EU", "name" => "Europe" },
    "NI" => { "code" => "NA", "name" => "North America" },
    "NL" => { "code" => "EU", "name" => "Europe" },
    "NO" => { "code" => "EU", "name" => "Europe" },
    "NA" => { "code" => "AF", "name" => "Africa" },
    "VU" => { "code" => "OC", "name" => "Oceania" },
    "NC" => { "code" => "OC", "name" => "Oceania" },
    "NE" => { "code" => "AF", "name" => "Africa" },
    "NF" => { "code" => "OC", "name" => "Oceania" },
    "NG" => { "code" => "AF", "name" => "Africa" },
    "NZ" => { "code" => "OC", "name" => "Oceania" },
    "NP" => { "code" => "AS", "name" => "Asia" },
    "NR" => { "code" => "OC", "name" => "Oceania" },
    "NU" => { "code" => "OC", "name" => "Oceania" },
    "CK" => { "code" => "OC", "name" => "Oceania" },
    "XK" => { "code" => "EU", "name" => "Europe" },
    "CI" => { "code" => "AF", "name" => "Africa" },
    "CH" => { "code" => "EU", "name" => "Europe" },
    "CO" => { "code" => "SA", "name" => "South America" },
    "CN" => { "code" => "AS", "name" => "Asia" },
    "CM" => { "code" => "AF", "name" => "Africa" },
    "CL" => { "code" => "SA", "name" => "South America" },
    "CC" => { "code" => "AS", "name" => "Asia" },
    "CA" => { "code" => "NA", "name" => "North America" },
    "CG" => { "code" => "AF", "name" => "Africa" },
    "CF" => { "code" => "AF", "name" => "Africa" },
    "CD" => { "code" => "AF", "name" => "Africa" },
    "CZ" => { "code" => "EU", "name" => "Europe" },
    "CY" => { "code" => "EU", "name" => "Europe" },
    "CX" => { "code" => "AS", "name" => "Asia" },
    "CR" => { "code" => "NA", "name" => "North America" },
    "CW" => { "code" => "NA", "name" => "North America" },
    "CV" => { "code" => "AF", "name" => "Africa" },
    "CU" => { "code" => "NA", "name" => "North America" },
    "SZ" => { "code" => "AF", "name" => "Africa" },
    "SY" => { "code" => "AS", "name" => "Asia" },
    "SX" => { "code" => "NA", "name" => "North America" },
    "KG" => { "code" => "AS", "name" => "Asia" },
    "KE" => { "code" => "AF", "name" => "Africa" },
    "SS" => { "code" => "AF", "name" => "Africa" },
    "SR" => { "code" => "SA", "name" => "South America" },
    "KI" => { "code" => "OC", "name" => "Oceania" },
    "KH" => { "code" => "AS", "name" => "Asia" },
    "KN" => { "code" => "NA", "name" => "North America" },
    "KM" => { "code" => "AF", "name" => "Africa" },
    "ST" => { "code" => "AF", "name" => "Africa" },
    "SK" => { "code" => "EU", "name" => "Europe" },
    "KR" => { "code" => "AS", "name" => "Asia" },
    "SI" => { "code" => "EU", "name" => "Europe" },
    "KP" => { "code" => "AS", "name" => "Asia" },
    "KW" => { "code" => "AS", "name" => "Asia" },
    "SN" => { "code" => "AF", "name" => "Africa" },
    "SM" => { "code" => "EU", "name" => "Europe" },
    "SL" => { "code" => "AF", "name" => "Africa" },
    "SC" => { "code" => "AF", "name" => "Africa" },
    "KZ" => { "code" => "AS", "name" => "Asia" },
    "KY" => { "code" => "NA", "name" => "North America" },
    "SG" => { "code" => "AS", "name" => "Asia" },
    "SE" => { "code" => "EU", "name" => "Europe" },
    "SD" => { "code" => "AF", "name" => "Africa" },
    "DO" => { "code" => "NA", "name" => "North America" },
    "DM" => { "code" => "NA", "name" => "North America" },
    "DJ" => { "code" => "AF", "name" => "Africa" },
    "DK" => { "code" => "EU", "name" => "Europe" },
    "VG" => { "code" => "NA", "name" => "North America" },
    "DE" => { "code" => "EU", "name" => "Europe" },
    "YE" => { "code" => "AS", "name" => "Asia" },
    "DZ" => { "code" => "AF", "name" => "Africa" },
    "US" => { "code" => "NA", "name" => "North America" },
    "UY" => { "code" => "SA", "name" => "South America" },
    "YT" => { "code" => "AF", "name" => "Africa" },
    "UM" => { "code" => "OC", "name" => "Oceania" },
    "LB" => { "code" => "AS", "name" => "Asia" },
    "LC" => { "code" => "NA", "name" => "North America" },
    "LA" => { "code" => "AS", "name" => "Asia" },
    "TV" => { "code" => "OC", "name" => "Oceania" },
    "TW" => { "code" => "AS", "name" => "Asia" },
    "TT" => { "code" => "NA", "name" => "North America" },
    "TR" => { "code" => "AS", "name" => "Asia" },
    "LK" => { "code" => "AS", "name" => "Asia" },
    "LI" => { "code" => "EU", "name" => "Europe" },
    "LV" => { "code" => "EU", "name" => "Europe" },
    "TO" => { "code" => "OC", "name" => "Oceania" },
    "LT" => { "code" => "EU", "name" => "Europe" },
    "LU" => { "code" => "EU", "name" => "Europe" },
    "LR" => { "code" => "AF", "name" => "Africa" },
    "LS" => { "code" => "AF", "name" => "Africa" },
    "TH" => { "code" => "AS", "name" => "Asia" },
    "TF" => { "code" => "AN", "name" => "Antarctica" },
    "TG" => { "code" => "AF", "name" => "Africa" },
    "TD" => { "code" => "AF", "name" => "Africa" },
    "TC" => { "code" => "NA", "name" => "North America" },
    "LY" => { "code" => "AF", "name" => "Africa" },
    "VA" => { "code" => "EU", "name" => "Europe" },
    "VC" => { "code" => "NA", "name" => "North America" },
    "AE" => { "code" => "AS", "name" => "Asia" },
    "AD" => { "code" => "EU", "name" => "Europe" },
    "AG" => { "code" => "NA", "name" => "North America" },
    "AF" => { "code" => "AS", "name" => "Asia" },
    "AI" => { "code" => "NA", "name" => "North America" },
    "VI" => { "code" => "NA", "name" => "North America" },
    "IS" => { "code" => "EU", "name" => "Europe" },
    "IR" => { "code" => "AS", "name" => "Asia" },
    "AM" => { "code" => "AS", "name" => "Asia" },
    "AL" => { "code" => "EU", "name" => "Europe" },
    "AO" => { "code" => "AF", "name" => "Africa" },
    "AQ" => { "code" => "AN", "name" => "Antarctica" },
    "AS" => { "code" => "OC", "name" => "Oceania" },
    "AR" => { "code" => "SA", "name" => "South America" },
    "AU" => { "code" => "OC", "name" => "Oceania" },
    "AT" => { "code" => "EU", "name" => "Europe" },
    "AW" => { "code" => "NA", "name" => "North America" },
    "IN" => { "code" => "AS", "name" => "Asia" },
    "AX" => { "code" => "EU", "name" => "Europe" },
    "AZ" => { "code" => "AS", "name" => "Asia" },
    "IE" => { "code" => "EU", "name" => "Europe" },
    "ID" => { "code" => "AS", "name" => "Asia" },
    "UA" => { "code" => "EU", "name" => "Europe" },
    "QA" => { "code" => "AS", "name" => "Asia" },
    "MZ" => { "code" => "AF", "name" => "Africa" }
);

#-------------------------------------------------------------------------------

sub new {
    my ( $pkg, $token, %options ) = @_;

    my $self = {};
    $token = defined $token ? $token : '';

    $self->{base_url}      = $base_url;
    $self->{base_url_ipv6} = $base_url_ipv6;
    $self->{ua}            = LWP::UserAgent->new;
    $self->{ua}->ssl_opts( 'verify_hostname' => 0 );
    $self->{ua}->default_headers(
        HTTP::Headers->new(
            Accept        => 'application/json',
            Authorization => 'Bearer ' . $token
        )
    );
    $self->{ua}->agent("IPinfoClient/Perl/$VERSION");

    my $timeout =
      defined $options{timeout} ? $options{timeout} : DEFAULT_TIMEOUT;
    $self->{ua}->timeout($timeout);

    $self->{message} = '';

    bless $self, $pkg;

    my $countries =
      exists $options{countries} ? $options{countries} : \%default_countries;
    my $eu_countries =
      exists $options{eu_countries}
      ? $options{eu_countries}
      : \@default_eu_countries;
    my $countries_flags =
      exists $options{countries_flags}
      ? $options{countries_flags}
      : \%default_countries_flags;
    my $countries_currencies =
      exists $options{countries_currencies}
      ? $options{countries_currencies}
      : \%default_countries_currencies;
    my $continents =
      exists $options{continents}
      ? $options{continents}
      : \%default_continents;

    $self->{countries}            = $countries;
    $self->{eu_countries}         = $eu_countries;
    $self->{countries_flags}      = $countries_flags;
    $self->{countries_currencies} = $countries_currencies;
    $self->{continents}           = $continents;
    $self->{cache}                = $self->_build_cache(%options);

    return $self;
}

#-------------------------------------------------------------------------------

sub info {
    my ( $self, $ip ) = @_;

    return $self->_get_info( $ip, '', 0 );
}

#-------------------------------------------------------------------------------

sub info_v6 {
    my ( $self, $ip ) = @_;

    return $self->_get_info( $ip, '', 1 );
}

#-------------------------------------------------------------------------------

sub geo {
    my ( $self, $ip ) = @_;

    return $self->_get_info( $ip, 'geo', 0 );
}

#-------------------------------------------------------------------------------

sub field {
    my ( $self, $ip, $field ) = @_;

    if ( not defined $field ) {
        $self->{message} = 'Field must be defined.';
        return;
    }

    if ( not defined $valid_fields{$field} ) {
        $self->{message} = "Invalid field: $field";
        return;
    }

    return $self->_get_info( $ip, $field, 0 );
}

#-------------------------------------------------------------------------------

sub error_msg {
    my $self = shift;

    return $self->{message};
}

#-------------------------------------------------------------------------------
#-- private method(s) below, don't call them directly -------------------------

sub _get_info {
    my ( $self, $ip, $field, $ipv6_lookup ) = @_;

    $ip    = defined $ip    ? $ip    : '';
    $field = defined $field ? $field : '';

    if ( $ip ne '' ) {
        my $validated_ip = Net::CIDR::cidrvalidate($ip);
        if ( !defined $validated_ip ) {
            $self->{message} = 'Invalid IP address';
            return undef;
        }
    }

    my ( $info, $message ) = $self->_lookup_info( $ip, $field, $ipv6_lookup );
    $self->{message} = $message;
    return $info if eval { $info->isa('Geo::Details') };

    if ( $field ne '' && ref($info) eq 'HASH' ) {
        if ( exists $info->{'bogon'} ) {
            $self->{message} = 'Field info not available for bogon IPs';
            return undef;
        }
    }

    return defined $info ? Geo::Details->new( $info, $field ) : undef;
}

sub _lookup_info {
    my ( $self, $ip, $field, $ipv6_lookup ) = @_;

    # checking bogon IP and returning response locally.
    if ( $ip ne '' ) {
        if ( _is_bogon($ip) ) {
            my $details = {};
            $details->{ip}    = $ip;
            $details->{bogon} = "True";
            return ( $details, '' );
        }
    }

    my $key         = $ip . '/' . $field;
    my $cached_info = $self->_lookup_info_from_cache($key);

    if ( defined $cached_info ) {
        return ( $cached_info, '' );
    }

    my ( $source_info, $message ) = $self->_lookup_info_from_source($ipv6_lookup, $key);
    if ( not defined $source_info ) {
        return ( $source_info, $message );
    }

    if ( ref($source_info) eq '' ) {
        return ( $source_info, $message );
    }

    my $country = $source_info->{country};
    if ( defined $country ) {
        $source_info->{country_name} = $self->{countries}->{$country};
        $source_info->{country_flag} = $self->{countries_flags}->{$country};
        $source_info->{country_flag_url} =
          $country_flag_url . $country . ".svg";
        $source_info->{country_currency} =
          $self->{countries_currencies}->{$country};
        $source_info->{continent} = $self->{continents}->{$country};
        if ( grep { $_ eq $country } @{ $self->{eu_countries} } ) {
            $source_info->{is_eu} = "True";
        }
        else {
            $source_info->{is_eu} = undef;
        }
    }

    if ( defined $source_info->{'loc'} ) {
        my ( $lat, $lon ) = split /,/, $source_info->{loc};
        $source_info->{latitude}  = $lat;
        $source_info->{longitude} = $lon;
    }

    $source_info->{meta} = { time => time(), from_cache => 0 };
    $self->{cache}->set( $key, $source_info );

    return ( $source_info, $message );
}

sub _lookup_info_from_cache {
    my ( $self, $cache_key ) = @_;

    my $cached_info = $self->{cache}->get($cache_key);
    if ( defined $cached_info ) {
        my $timedelta = time() - $cached_info->{meta}->{time};
        if ( $timedelta <= $cache_ttl || $custom_cache == 1 ) {
            $cached_info->{meta}->{from_cache} = 1;

            return $cached_info;
        }
    }

    return;
}

sub _lookup_info_from_source {
    my ( $self, $is_ipv6, $key ) = @_;

    my $url = '';
    if ( $is_ipv6 ) {
        $url = $self->{base_url_ipv6} . $key;
    } else {
        $url = $self->{base_url} . $key;
    }

    my $response = $self->{ua}->get($url);

    if ( $response->is_success ) {

        my $content_type = $response->header('Content-Type') || '';
        my $info;

        if ( $content_type =~ m{application/json}i ) {
            eval { $info = from_json( $response->decoded_content ); };
            if ($@) {
                return ( undef, 'Error parsing JSON response.' );
            }
        }
        else {
            $info = $response->decoded_content;
            chomp($info);
        }

        return ( $info, '' );
    }
    if ( $response->code == HTTP_TOO_MANY_REQUEST ) {
        return ( undef, 'Your monthly request quota has been exceeded.' );
    }

    return ( undef, $response->status_line );
}

sub _build_cache {
    my ( $pkg, %options ) = @_;

    if ( defined $options{cache} ) {
        $custom_cache = 1;

        return $options{cache};
    }

    $cache_ttl = DEFAULT_CACHE_TTL;
    if ( defined $options{cache_ttl} ) {
        $cache_ttl = $options{cache_ttl};
    }

    return Cache::LRU->new(
        size => defined $options{cache_max_size}
        ? $options{cache_max_size}
        : DEFAULT_CACHE_MAX_SIZE
    );
}

# Lists of bogon CIDRs.
my @ip4_bogon_networks = (
    "0.0.0.0/8",       "10.0.0.0/8",
    "100.64.0.0/10",   "127.0.0.0/8",
    "169.254.0.0/16",  "172.16.0.0/12",
    "192.0.0.0/24",    "192.0.2.0/24",
    "192.168.0.0/16",  "198.18.0.0/15",
    "198.51.100.0/24", "203.0.113.0/24",
    "224.0.0.0/4",     "240.0.0.0/4",
    "255.255.255.255/32"
);
my @ip6_bogon_networks = (
    "0:0:0:0:0:0:0:0/128",   "0:0:0:0:0:0:0:1/128",
    "0:0:0:0:0:ffff:0:0/96", "0:0:0:0:0:0:0:0/96",
    "100::/64",              "2001:10::/28",
    "2001:db8::/32",         "fc00::/7",
    "fe80::/10",             "fec0::/10",
    "ff00::/8",              "2002::/24",
    "2002:a00::/24",         "2002:7f00::/24",
    "2002:a9fe::/32",        "2002:ac10::/28",
    "2002:c000::/40",        "2002:c000:200::/40",
    "2002:c0a8::/32",        "2002:c612::/31",
    "2002:c633:6400::/40",   "2002:cb00:7100::/40",
    "2002:e000::/20",        "2002:f000::/20",
    "2002:ffff:ffff::/48",   "2001::/40",
    "2001:0:a00::/40",       "2001:0:7f00::/40",
    "2001:0:a9fe::/48",      "2001:0:ac10::/44",
    "2001:0:c000::/56",      "2001:0:c000:200::/56",
    "2001:0:c0a8::/48",      "2001:0:c612::/47",
    "2001:0:c633:6400::/56", "2001:0:cb00:7100::/56",
    "2001:0:e000::/36",      "2001:0:f000::/36",
    "2001:0:ffff:ffff::/64"
);

# Check if an IP address is a bogon.
sub _is_bogon {
    my $ip = shift;

    my $ip_is_bogon = 0;

    if ( $ip =~ /:/ ) {    # IPv6 address
        my $ip6_bogon_cidr_set = Net::CIDR::Set->new();
        $ip6_bogon_cidr_set->add($_) foreach (@ip6_bogon_networks);
        $ip_is_bogon = $ip6_bogon_cidr_set->contains($ip);
    }
    else {                 # IPv4 address
        my $ip4_bogon_cidr_set = Net::CIDR::Set->new();
        $ip4_bogon_cidr_set->add($_) foreach (@ip4_bogon_networks);
        $ip_is_bogon = $ip4_bogon_cidr_set->contains($ip);
    }

    return $ip_is_bogon;
}

#-------------------------------------------------------------------------------

1;
__END__


=head1 NAME

Geo::IPinfo -  The official Perl library for IPinfo.

=head1 VERSION

Version 3.0.1

=cut

=head1 SYNOPSIS

Geo::IP The official Perl library for IPinfo. IPinfo prides itself on being the most reliable, accurate, and in-depth source of IP address data available anywhere. We process terabytes of data to produce our custom IP geolocation, company, carrier and IP type data sets. You can visit our developer docs at https://ipinfo.io/developers.

A quick usage example:

    use Geo::IPinfo;

    $access_token = '123456789abc';
    $ipinfo = Geo::IPinfo->new($access_token);

    $ip_address = '216.239.36.21';
    $details = $ipinfo->info($ip_address);
    $city = $details->city; # Mountain View
    $loc = $details->loc; # 37.4056,-122.0775

    $ip_address = '2001:4860:4860::8888';
    $details = $ipinfo->info_v6($ip_address);
    $city = $details->city; # Mountain View
    $loc = $details->loc; # 37.4056,-122.0775

=head1 SUBROUTINES/METHODS

=head2 new([token], [options])

Create an ipinfo object. The 'token' (string value) and 'options' (hash value) arguments are optional.

If 'token' is specified, then it's used to overcome the default
non-commercial limitation of 1,000 request/day (For more details, see L<https://ipinfo.io/pricing>)

if 'options' is specfied, the included values will allow control over cache policies and country name localization (For more details, see L<https://github.com/ipinfo/perl>).

=cut

=head2 info(ip_address)

Returns a reference to a Details object containing all information related to the IPv4 address. In case
of errors, returns undef, the error message can be retrieved with the function 'error_msg()'

The values can be accessed with the named methods: ip, org, domains, privacy, abuse, timezone, hostname, city, country, country_name, country_flag,
country_flag_url, country_currency, continent, is_eu, loc, latitude, longitude, postal, asn, company, meta, carrier, and all.

=head2 info_v6(ip_address)

Returns a reference to a Details object containing all information related to the IPv6 address. In case
of errors, returns undef, the error message can be retrieved with the function 'error_msg()'

The values can be accessed with the named methods: ip, org, domains, privacy, abuse, timezone, hostname, city, country, country_name, country_flag,
country_flag_url, country_currency, continent, is_eu, loc, latitude, longitude, postal, asn, company, meta, carrier, and all.

=head2 geo(ip_address)

Returns a reference to an object containing only the geolocation related data. Returns undef
in case of errors, the error message can be retrieved with the function 'error_msg'

It's usually faster than getting the full response using 'info()'

The values returned are: ip, city, org, loc, latitude, longitude, hostname, is_eu, country, country_name, country_flag,
country_flag_url, country_currency, meta, continent, postal, region, and timezone.

=head2 field(ip_address, field_name)

Returns a reference to an object containing only the field related data. Returns undef
if the field is invalid

The possible values of 'field_name' are: ip, hostname, city, region, country, loc, org, postal, timezone, geo, asn,
company, privacy, abuse, and domains.

=head2 error_msg( )

Returns a string containing the error message of the last operation, it returns an empty
string if the last operation was successful

=cut

=head1 AUTHOR

Ben Dowling, C<< <ben at ipinfo dot io> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-geo-ipinfo at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Geo-IPinfo>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Geo::IPinfo


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Geo-IPinfo>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Geo-IPinfo>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Geo-IPinfo>

=item * Search CPAN

L<http://search.cpan.org/dist/Geo-IPinfo/>

=item * GitHub

L<https://github.com/ipinfo/perl>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2019 ipinfo.io.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

L<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


=cut

# End of Geo::IPinfo
