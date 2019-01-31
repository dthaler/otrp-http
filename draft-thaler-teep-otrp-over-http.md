---
title: HTTP Transport for the Open Trust Protocol (OTrP)
abbrev: OTrP HTTP Transport
docname: draft-thaler-teep-otrp-over-http-00
category: info

ipr: trust200902
area: Security
workgroup: TEEP WG
keyword: Internet-Draft

stand_alone: yes
pi:
  rfcedstyle: yes
  toc: yes
  tocindent: yes
  sortrefs: yes
  symrefs: yes
  strict: yes
  comments: yes
  inline: yes
  text-list-symbols: -o*+
  docmapping: yes
author:
 -
       ins: D. Thaler
       name: David Thaler
       organization: Microsoft
       email: dthaler@microsoft.com

--- abstract

This document specifies the HTTP transport for the Open Trust Protocol (OTrP),
which is used to manage code and configuration data in a Trusted Execution
Environment (TEE).  An implementation of this document can run outside of any TEE,
but interacts with an implementation of OTrP that runs inside a TEE.

--- middle


#  Introduction

Trusted Execution Environments (TEEs), including Intel SGX, ARM TrustZone,
Secure Elements, and others, enforce that only authorized code can execute within the TEE,
and any memory used by such code can be protected against tampering or
disclosure outside the TEE.  The Open Trust Protocol (OTrP) is designed to
provision authorized code and configuration into TEEs.

To be secure against malware, an OTrP implementation (referred to as an 
OTrP "Agent" on the client side, and a "Trusted Application Manager (TAM)" on
the server side) must themselves run inside a TEE. However, the transport for OTrP,
along with typical networking stacks, need not run inside a TEE.  This split allows
keeping the set of highly trusted code as small as possible, and allowing code
(e.g., TCP/IP) that only sees encrypted messages to be kept out of the TEE.

The OTrP specification {{!I-D.ietf-teep-opentrustprotocol}} describes the
behavior of OTrP Agents and TAMs, but does not specify the details of the transport,
an implementation of which is referred to as a
"Broker".  The purpose of this document is to provide such details.  That is,
the HTTP transport for OTrP is implemented in a Broker (typically outside
a TEE) that delivers messages up to an OTrP implementation, and accepts
messages from the OTrP implementation to be sent over a network.

# Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY",
and "OPTIONAL" in this document are to be interpreted as described
in BCP 14 {{!RFC2119}} {{!RFC8174}} when, and only when, they appear
in all capitals, as shown here.

This document also uses various terms defined in
{{?I-D.ietf-teep-architecture}}, including Trusted Execution Environment (TEE),
Trusted Application (TA), Trusted Application Manager (TAM), Agent, and Broker.

# Use of Abstract APIs

This document refers to various APIs between a Broker and an OTrP implementation
in the abstract, meaning the literal syntax and programming language
are not specified, so that various concrete APIs can be designed
(outside of the IETF) that are compliant.

It is common in some TEE architectures (e.g., SGX) to refer to calls
into a Trusted Application (TA) as "ECALLs" (or enclave-calls), and calls
out from a Trusted Application (TA) as "OCALLs" (or out-calls).

In other TEE architectures, there may be no OCALLs, but merely data returned
from calls into a TA.  This document attempts to be agnostic as to the
concrete API architecture.  As such, abstract APIs used in this document
will refer to calls into a TA as API calls, and will simply refer to
"passing data" back out of the TA.  A concrete API might pass data
back via an OCALL or via data returned from an API call.

This document will also refer to passing "no" data back out of a TA.
In an OCALL-based architecture, this might be implemented by not making
any such call.  In a return-based architecture, this might be implemented
by returning 0 bytes.

# Client Broker Behavior

## Receiving a request to install a new Trusted Application

When the Broker receives a notification (e.g., from an application installer)
that an application has a dependency on a given Trusted Application (TA)
being available in a given type of TEE, the notification will contain the following:

 - A unique identifier of the TA

 - Optionally, any metadata to pass to the Agent.  This might
   include a TAM URI provided in the application manifest, for example.

 - Optionally, any requirements that may affect the choice of TEE,
   if multiple are available to the Broker.

When such a notification is received, the Broker first identifies
in an implementation-dependent way which TEE (if any) is most appropriate
based on the constraints expressed.  If there is only one TEE, the choice
is obvious.  Otherwise, the choice might be based on factors such as
capabilities of available TEE(s) compared with TEE requirements in the notification.

The Broker MUST then inform the OTrP Agent in that TEE by invoking
an appropriate "RequestTA" API that identifies the TA needed and any other
associated metadata.  The Broker need not know whether the TEE already has
such a TA installed or whether it is up to date.

The OTrP Agent will either (a) pass no data back, (b) pass back a TAM URI to connect to,
or (c) pass back a message buffer and TAM URI to send it to.

### Session Creation {#client-start}

If no data is passed back, the Broker simply informs its client (e.g., the
application installer) of success.

If the OTrP Agent passes back a TAM URI with no message buffer, the TEEP Broker
attempts to create session state,
then sends an HTTP(S) GET to the TAM URI with an "Accept: application/json" header
 and an empty body. The HTTP request is then associated with the Broker's session state.

If the OTrP Agent instead passes back a TAM URI with a message buffer, the TEEP Broker
attempts to create session state and handles the message buffer as
specified in {{send-msg}}.

Session state consists of:

 - Any context (e.g., a handle) that identifies the API session with the OTrP Agent.

 - Any context that identifies an HTTP request, if one is outstanding.  Initially, none exists.

## Getting a message buffer back from an OTrP Agent {#send-msg}

When a message buffer (and TAM URI) is passed to a Broker from an OTrP Agent, the
Broker MUST do the following, using the Broker's session state associated
with its API call to the OTrP Agent.

The Broker sends an HTTP POST request to the TAM URI with "Accept: application/json"
and "Content-type: application/json" headers, and a body
containing the OTrP message buffer provided by the OTrP Agent.
The HTTP request is then associated with the Broker's session state.

## Receiving an HTTP response {#http-response}

When an HTTP response is received in response to a request associated
with a given session state, the Broker MUST do the following.

If the HTTP response body is empty, the Broker's task is complete, and
it can delete its session state, and its task is done.

If instead the HTTP response body is not empty,
the Broker calls a "ProcessOTrPMessage" API (Section 6.2 of {{I-D.ietf-teep-opentrustprotocol}})
to pass the response body to the OTrP Agent
associated with the session.  The OTrP Agent will then pass no data back,
or pass pack a message buffer.

If no data is passed back, the Broker's task is complete, and it
can delete its session state, and inform its client (e.g., the application
installer) of success.

If instead the OTrP Agent passes a message buffer, the TEEP Broker
handles the message buffer as specified in {{send-msg}}.

## Handling checks for policy changes

An implementation MUST provide a way to periodically check for OTrP policy changes.
This can be done in any implementation-specific manner, such as:

A) The Broker might call into the Agent at an interval previously specified by the Agent.
   This approach requires that the Broker be capable of running a periodic timer.

B) The Broker might be informed when an existing TA is invoked, and call into the Agent if
   more time has passed than was previously specified by the Agent.  This approach allows
   the device to go to sleep for a potentially long period of time.

C) The Broker might be informed when any attestation attempt determines that the device
   is out of compliance, and call into the Agent to remediate.

The Broker informs the OTrP Agent by invoking an appropriate "RequestPolicyCheck" API.
The OTrP Agent will either (a) pass no data back, (b) pass back a TAM URI to connect to,
or (c) pass back a message buffer and TAM URI to send it to.  Processing then continues
as specified in {{client-start}}.

## Error handling

If any local error occurs where the Broker cannot get
a message buffer (empty or not) back from the Agent, the
Broker deletes its session state, and informs its client (e.g.,
the application installer) of a failure.

If any HTTP request results in an HTTP error response or
a lower layer error (e.g., network unreachable), the
Broker calls the Agent's "ProcessError" API, and then
deletes its session state and informs its client of a failure.

# Server Broker Behavior

## Receiving an HTTP GET request

When an HTTP GET request is received, the Broker invokes the
TAM's "ProcessConnect" API.  The TAM will then pass back
a (possibly empty) message buffer.

## Receiving an HTTP POST request

When an HTTP POST request is received, the Broker calls the TAM's
"ProcessOTrPMessage" API to pass it the request body. The TAM will 
then pass back a (possibly empty) message buffer.

## Getting an empty buffer back from the TAM

If the TAM passes back an empty buffer, the Broker sends a 200 OK response 
with no body.

## Getting a message buffer from the TAM

If the TAM passes back a non-empty buffer, the Broker
generates a 200 OK response with a "Content-type: application/json"
header, and with the message buffer as the body.

## Error handling

If any error occurs where the Broker cannot get
a message buffer (empty or not) back from the TAM, the
Broker generates an appropriate HTTP error response.

# Sample message flow

1. An application installer determines (e.g., from an app manifest)
   that the application has a dependency on TA "X", and passes
   this notification to the Client Broker.  The Client Broker
   picks an OTrP Agent (e.g., the only one available) based on
   this notification.

2. The Client Broker calls the Agent's "RequestTA" API, passing
   TA Needed = X.

3. The OTrP Agent finds that no such TA is already installed,
   but that it can be obtained from a given TAM.  The OTrP
   Agent passes the TAM URI to the Client Broker.  (If the OTrP
   Agent already had a cached TAM certificate that it trusts,
   it could skip to step 9 instead and generate a GetDeviceStateResponse.)

4. The Client Broker sends an HTTP GET request to the TAM URI,
   with an "Accept: application/json" header.

5. The Server Broker receives the HTTP GET request, and calls
   the TAM's "ProcessConnect" API.

6. The TAM generates an OTrP message (typically GetDeviceStateRequest
   is the first message) and passes it to the Server Broker.

7. The Server Broker sends an HTTP 200 OK response with a
   "Content-type: application/json" header, and the OTrP message
   in the body.

8. The Client Broker gets the HTTP response, extracts the OTrP
   message and calls the Agent's "ProcessOTrPMessage" API to pass it the message.

9. The Agent processes the OTrP message, and generates an OTrP
   response (e.g., GetDeviceStateResponse) which it passes back
   to the Client Broker.

10. The Client Broker gets the OTrP message buffer and sends
    an HTTP POST request to the TAM URI, with
    "Content-type: application/json" and "Accept: application/json".

11. The Server Broker receives the HTTP POST request, and calls
    the TAM's "ProcessOTrPMessage" API.

12. Steps 6-11 are then repeated until the TAM passes no data back
    to the Server Broker in step 6.

13. The Server Broker sends an HTTP 200 OK response with
    no body.

14. The Client Broker deletes its session state.

# Security Considerations

Although OTrP is protected end-to-end inside of HTTP, there is still value
in using HTTPS for transport, since HTTPS can provides stronger protections
as discussed in Section 6 of {{?I-D.ietf-httpbis-bcp56bis}}.  As such, Broker
implementations MUST support HTTPS.  The choice of HTTP vs HTTPS at runtime
is up to policy, where an administrator configures the TAM URI to be used,
but it is expected that real deployments always use HTTPS.

#  IANA Considerations

This document does not require actions by IANA.

--- back