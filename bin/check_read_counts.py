#!/usr/bin/env python3
import sys, os

def count_pod5(path):
    try:
        from pod5 import Reader
    except Exception as e:
        print(f"ERROR: pod5 Python library not available: {e}", file=sys.stderr)
        return 0
    c = 0
    with Reader(path) as r:
        try:
            for _ in r:
                c += 1
        except TypeError:
            for _ in r.reads():
                c += 1
    return c

def count_fast5(path):
    try:
        import h5py
    except Exception as e:
        print(f"ERROR: h5py library not available: {e}", file=sys.stderr)
        return 0
    c = 0
    with h5py.File(path, 'r') as f:
        if 'Raw' in f and 'Reads' in f['Raw']:
            try:
                c += len(f['Raw']['Reads'])
            except Exception:
                pass
        else:
            try:
                c += sum(1 for k in f.keys() if k.startswith('read_'))
            except Exception:
                pass
    return c

def main():
    if len(sys.argv) < 2:
        print("Usage: check_read_counts.py <chunk_file_list>", file=sys.stderr)
        sys.exit(2)
    list_path = sys.argv[1]
    total = 0
    with open(list_path) as fh:
        for line in fh:
            p = line.strip()
            if not p or not os.path.exists(p):
                continue
            if p.lower().endswith('.pod5'):
                total += count_pod5(p)
            elif p.lower().endswith('.fast5'):
                total += count_fast5(p)
    print(total)

if __name__ == "__main__":
    main()