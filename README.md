# SystemVerilog Design and Verification 10000 Counter
미니프로젝트 : SystemVerilog를 이용하여 10,000 Counter 설계 및 검증


PPT link : [PPT 바로보기](https://www.canva.com/design/DAGyvS3EGzo/xglLc3FiXX4jeBjt4sGhaQ/view?utm_content=DAGyvS3EGzo&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=hb298409a0d)


## 🔹프로젝트 개요


- Verilog HDL만으로는 복잡한 SoC 내부 모듈들의 상호작용을 검증하기 어렵기 때문에 버그를 조기에, 효율적으로 찾아내기 위해서는 SystemVerilog와 같은 검증언어의 중요성이 커지고 있습니다.

- 본 프로젝트는 10,000 Counter와 UART, FIFO, Counter 모듈을 통합 설계하고 재사용성과 확장성이 뛰어난 **SystemVerilog의 객체지향(OOP)기반 Testbench 환경**을 구축하여 검증 효율을 극대화하는 것을 목표로 했습니다.

- 이를 위해 랜덤 데이터 생성(Randomization), 클래스 기반의 검증 환경(Generator, Driver, Monitor, Scoreboard) 그리고 모듈간의 동기화를 위한 Mailbox 통신을 이용한 검증 기법을 적용했습니다. 

## 🔹프로젝트 목표


- 10,000 Counter 및 UART, FIFO 모듈 설계 및 통합 검증
- 체계적 검증 환경 구현을 위해 System Verilog 기반 OOP Testbench 구축
- 다양한 시나리오에서 안정성 검증을 위한 Random Test 및 Assertion 활용

## 🔹설계 및 검증



### 🔹설계 (**Design)**

- **Counter 모듈 : Run/Stop, Clear, Mode 전환 (Increase/ Decrease) 기능**
- **UART RX/TX, FIFO**
- **Control Unit**
- **FND Controller**
- **Data Path**



### 🔹검증 환경 (Verification Environment)

- **Generator : Random Stimulus 생성**
- **Driver : Interface로 Data 전달**
- **Monitor : Interface에서 Data 받기**
- **Scoreboard : Generator와 Monitor의 Data 비교를 통해 PASS/FAIL 확인**

### 🔹 TASK(맡은 역할)



**🔸 설계 (Design)**

- **UART RX/TX : Start/Data/Stop 비트를 포함한 직렬 통신 로직 구현**
- **FIFO : Register File을 설계하여 FIFO(First in - First out) 데이터 버퍼링 기능 구현**
- **Counter : Run/Stop, Clear, Mode 전환 (Increase/ Decrease) 기능 구현**
- **Control Unit : UART 통신을 통해 들어온 문자열에 따른 동작 제어**
- **Data Path : 데이터 연산 및 시간 카운팅**
- **FND Controller : Data Path로부터 받은 시간 데이터를 7-Segment Display에 맞는 숫자 신호로 변환 및 출력**

**🔸 검증 (Verification)**

- **UART FIFO : Normal case 및 Full / Empty corner Case 검증**
- **UART TX : 데이터 무결성, 통신 프로토콜에 따른 데이터 송신 그리고 상태 신호(tx_busy) 동작 검증**

### 🔹System Architecture

![counter_top_blockdiagram.jpg](https://github.com/seonghunppark/SystemVerilog-Design-and-Verification-10000-Counter-/blob/f47c453825b62bf56580ae50dce4bd8033951a0c/counter_top_blockdiagram.jpg)

## 🔹주요 성과 및 배운 점 (Outcome & Lessons Learned)

1. UART RX feature Verification
2. FIFO Full & Empty Verification
3. UART TX feature Verification
4. UART TOP feature Verification 
5. 10,000 Counter feature Simulation 

**[검증의 체계화: UVM 구조를 이용한 검증]**

**1. 체계적 검증의 필요성 인식**
FPGA 기반의 RISC-V CPU 설계 및 센서 제어 프로젝트를 수행하며, 설계 복잡도가 증가함에 따라 기존의 단순 테스트벤치 방식으로는 모든 코너 케이스(Corner Case)를 커버하기 어렵다는 한계를 느꼈습니다. 특히, 모듈 간의 인터페이스 오류를 사전에 차단하기 위해 **검증 환경의 재사용성과 독립성**이 핵심임을 깨달았습니다.

**2. UVM 유사 구조의 검증 환경 구축**
이를 해결하기 위해 검증 환경을 **Driver, Monitor, Scoreboard**와 유사한 역할로 분리하여 체계화했습니다.

- **데이터 생성 및 주입(Generator & Driver):** 시나리오를 바탕으로 다양한 테스트 벡터를 전송했습니다.
- **모니터링(Monitor):** 설계 내부의 신호를 실시간으로 관찰하고 로그를 기록하여 데이터의 흐름을 추적했습니다.
- **결과 비교 및 분석(Scoreboard):** Python을 활용해 도출한 이론적 기댓값과 실제 시뮬레이션 결과값을 실시간으로 비교 분석하는 자동화 로직을 구현했습니다.

## 관련 멤버

- 김철종 [UART TOP, RX Verification and Counter Simulation]
