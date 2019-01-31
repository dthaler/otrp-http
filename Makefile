draft-thaler-teep-otrp-over-http.txt: draft-thaler-teep-otrp-over-http.xml
	xml2rfc draft-thaler-teep-otrp-over-http.xml

draft-thaler-teep-otrp-over-http.xml: draft-thaler-teep-otrp-over-http.md
	kramdown-rfc2629 draft-thaler-teep-otrp-over-http.md > draft-thaler-teep-otrp-over-http.xml
