.. only:: latex

    Introduction
    ==============
    
    .. raw:: latex

        \vspace*{\fill}

    Copyright (c) 2020 The HSC Core Authors (Kevin Dai and Anthony Kung)
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        https://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "as is" basis,
    without warranties or conditions of any kind, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    .. raw:: latex

        \vspace*{0.25in}

Introduction
===============================================================================

HSC designs and develops both the ISA and SoC IPs indepedently.
The HS32 ISA is implemented by the HS32 Core and is distinct from the
from the SoC architecture.

Open-source Licensing
-------------------------------------------------------------------------------

This documentation, HS32 and all non third-party IPs and tools are
fully open-source and licensed under Apache 2.0.

Repository
-------------------------------------------------------------------------------

The HS32 SoC IPs are hosted on git at
`hsc-latte/hs32core-rtl <https://github.com/hsc-latte/hs32core-rtl/>`_.
The HS32 SoC modified to integrate with Caravel can be found at
`hsc-latte/caravel-hs32 <https://github.com/hsc-latte/caravel-hs32core>`_.

Target Process Node
-------------------------------------------------------------------------------

Currently, the HS32 SoC design targets the 130nm Skywater process described in
`google/skywater-pdk <https://github.com/google/skywater-pdk>`_.
Additionally, the open-source design of the Caravel management SoC can also be
found at `efabless/caravel <https://github.com/efabless/caravel>`_.
