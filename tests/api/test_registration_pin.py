def test_register_accepts_camel_case_pin(api_client):
    response = api_client.post(
        "/users/register",
        json={
            "name": "Alias User",
            "email": "alias@example.com",
            "password": "password",
            "gender": "male",
            "pinCode": "9876",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["has_pin"] is True

    verify = api_client.post(
        f"/users/{data['id']}/verify_pin",
        json={"pin_code": "9876"},
    )
    assert verify.status_code == 200
    assert verify.json() == {"valid": True}
