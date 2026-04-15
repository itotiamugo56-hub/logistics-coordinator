use criterion::{criterion_group, criterion_main, Criterion, BenchmarkId};
use geoh3_index::*;

fn bench_lat_lng_conversion(c: &mut Criterion) {
    let coords = vec![
        (40.756, -73.986),
        (51.507, -0.127),
        (35.689, 139.692),
        (-33.868, 151.209),
    ];
    
    let mut group = c.benchmark_group("h3_conversion");
    for (lat, lng) in coords {
        group.bench_with_input(BenchmarkId::new("lat_lng_to_h3", format!("{}_{}", lat, lng)), &(lat, lng), |b, &(lat, lng)| {
            b.iter(|| lat_lng_to_h3(lat, lng, 9).unwrap())
        });
    }
    group.finish();
}

fn bench_k_ring(c: &mut Criterion) {
    let h3 = lat_lng_to_h3(40.756, -73.986, 9).unwrap();
    
    c.bench_function("k_ring_k1", |b| {
        b.iter(|| k_ring(h3, 1))
    });
    
    c.bench_function("k_ring_k2", |b| {
        b.iter(|| k_ring(h3, 2))
    });
}

fn bench_distance_calculation(c: &mut Criterion) {
    let h3_1 = lat_lng_to_h3(40.756, -73.986, 9).unwrap();
    let h3_2 = lat_lng_to_h3(40.758, -73.984, 9).unwrap();
    
    c.bench_function("h3_distance", |b| {
        b.iter(|| h3_distance_meters(h3_1, h3_2))
    });
}

criterion_group!(benches, bench_lat_lng_conversion, bench_k_ring, bench_distance_calculation);
criterion_main!(benches);