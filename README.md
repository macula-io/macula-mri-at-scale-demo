# Macula MRI at Scale Demo

Interactive LiveView demonstration of Macula Resource Identifiers (MRI) at telecom scale.

## Features

- **Real-time Network Generation** - Watch as thousands of MRIs are created
- **Proximus Network Simulation** - Belgian telecom topology with ~4,000 SRPs and ~1M homes at full scale
- **Performance Benchmarks** - Measure lookup, query, and aggregation performance
- **Beautiful UI** - Modern dark theme with live progress updates

## Quick Start

```bash
# Install dependencies
mix setup

# Start the server
mix phx.server
```

Then visit [http://localhost:4000](http://localhost:4000).

## Usage

1. **Initialize Store** - Click to start the Khepri storage backend
2. **Adjust Scale** - Use the slider to set network size (1% to 100%)
3. **Generate Network** - Create SRPs and home connections with live progress
4. **Run Benchmark** - Measure query performance

## Scale Reference

| Scale | SRPs | Homes |
|-------|------|-------|
| 1% | ~40 | ~10K |
| 10% | ~400 | ~100K |
| 50% | ~2,000 | ~500K |
| 100% | ~4,000 | ~1M |

## Technology Stack

- **Phoenix LiveView** - Real-time reactive UI
- **Khepri** - Raft-consensus tree-based storage
- **Macula NIFs** - High-performance native operations
- **TailwindCSS** - Modern styling

## Architecture

```
MRI Format: mri:type:realm/segment1/segment2/...

Examples:
  mri:srp:be.proximus/brussels/srp-000001
  mri:home:be.proximus/flanders/srp-000042/home-00000001
```

MRIs are stored in Khepri's tree structure, enabling efficient hierarchical queries and Raft-based consensus for distributed deployments.

## License

Apache-2.0
