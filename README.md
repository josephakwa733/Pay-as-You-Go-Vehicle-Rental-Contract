# 🚗 Pay-as-You-Go Vehicle Rental Contract

A smart contract system for renting bikes, scooters, and cars with per-minute billing tracked through IoT integration on the Stacks blockchain.

## 🚀 Features

- 🚲 **Multi-Vehicle Support**: Register bikes, scooters, cars, and other vehicles
- ⏱️ **Pay-per-Minute**: Transparent billing based on actual usage time
- 💳 **Prepaid Balance**: Deposit funds and pay automatically from balance
- 🔒 **Smart Security**: Owner and emergency controls for vehicle management
- 📊 **Real-time Tracking**: Live cost calculation during active rentals
- 🛠️ **Flexible Rates**: Global and per-vehicle rate customization

## 📋 Contract Functions

### 🏗️ Vehicle Management

#### `register-vehicle`
Register a new vehicle for rental
```clarity
(contract-call? .contract register-vehicle "bike" "Downtown Station A")
```

#### `set-vehicle-rate`
Set custom rate for your vehicle (vehicle owners only)
```clarity
(contract-call? .contract set-vehicle-rate u1 (some u15))
```

### 💰 Payment System

#### `deposit-funds`
Add STX to your rental balance
```clarity
(contract-call? .contract deposit-funds u1000)
```

#### `withdraw-balance`
Withdraw unused funds from your balance
```clarity
(contract-call? .contract withdraw-balance u500)
```

### 🚗 Rental Operations

#### `start-rental`
Begin renting a vehicle
```clarity
(contract-call? .contract start-rental u1)
```

#### `end-rental`
Complete rental and process payment
```clarity
(contract-call? .contract end-rental u1)
```

#### `emergency-end-rental`
Emergency stop (vehicle owners and contract admin only)
```clarity
(contract-call? .contract emergency-end-rental u1)
```

### 📊 View Functions

#### `get-vehicle`
Get vehicle details
```clarity
(contract-call? .contract get-vehicle u1)
```

#### `get-user-balance`
Check user's prepaid balance
```clarity
(contract-call? .contract get-user-balance 'SP1ABC...)
```

#### `calculate-current-cost`
Get real-time cost for active rental
```clarity
(contract-call? .contract calculate-current-cost u1)
```

## 🎯 Usage Workflow

1. **Vehicle Owner**: Register vehicles using `register-vehicle`
2. **Renter**: Deposit funds with `deposit-funds`
3. **Renter**: Start rental with `start-rental`
4. **IoT System**: Monitors usage (simulated by block progression)
5. **Renter**: End rental with `end-rental` (automatic payment)
6. **Owner**: Receives payment directly to their address

## ⚙️ Configuration

- **Default Rate**: 10 microSTX per block (~10 minutes)
- **Rate Updates**: Contract owner can adjust global rates
- **Custom Rates**: Vehicle owners can set individual vehicle rates

## 🛡️ Security Features

- Only vehicle owners can modify their vehicles
- Only renters can end their active rentals
- Emergency controls for vehicle owners and contract admin
- Balance verification before rental completion
- Automatic payment processing with balance deduction

## 🔧 Technical Details

- **Language**: Clarity (Stacks blockchain)
- **Block Tracking**: Uses `stacks-block-height` for timing
- **Payment**: Direct STX transfers to vehicle owners
- **State Management**: Efficient mapping structures for scalability

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 📄 License

MIT License
